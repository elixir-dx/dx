defmodule Dx.DefdTest do
  use Dx.Test.DataCase, async: true

  import Dx.Defd

  defmacrop location(plus) do
    file = Path.relative_to_cwd(__CALLER__.file)
    quote do: "#{unquote(file)}:#{unquote(__CALLER__.line) + unquote(plus)}"
  end

  describe "constants" do
    defd bool_constant() do
      true
    end

    test "returns true" do
      assert load(bool_constant()) == {:ok, true}
    end

    test "emits compiler warning when called directly" do
      assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
               bool_constant()
             end) =~ "Use Dx.load as entrypoint"
    end
  end

  describe "simple arg" do
    defd simple_arg(arg) do
      arg
    end

    test "returns arg" do
      assert load(simple_arg(1)) == {:ok, 1}
    end
  end

  describe "calling other defd" do
    test "works" do
      defmodule Other do
        import Dx.Defd

        defd fun1(arg) do
          arg
        end
      end

      defmodule One do
        import Dx.Defd

        defd fun1(arg) do
          arg
        end

        defd fun2() do
          fun1("Hi!")
        end

        defd fun3() do
          __MODULE__.fun1("Hi!")
        end

        defd fun4() do
          Other.fun1("Hi!")
        end
      end

      assert load(One.fun2()) == {:ok, "Hi!"}
      assert load(One.fun3()) == {:ok, "Hi!"}
      assert load(One.fun4()) == {:ok, "Hi!"}

      assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
               load(One.fun2())
               load(One.fun3())
               load(One.fun4())
             end) == ""
    end
  end

  describe "calling non-defd functions" do
    test "non-defd local function" do
      assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
               defmodule Sample0 do
                 import Dx.Defd

                 defd add(a, b) do
                   do_add(a, b)
                 end

                 defp do_add(a, b), do: a + b
               end

               assert load(Sample0.add(1, 2)) == {:ok, 3}
             end) =~ "do_add/2 is not defined with defd"
    end

    test "non-defd local function wrapped in call/1" do
      refute ExUnit.CaptureIO.capture_io(:stderr, fn ->
               defmodule Sample0 do
                 import Dx.Defd

                 defd add(a, b) do
                   call(do_add(a, b))
                 end

                 defp do_add(a, b), do: a + b
               end

               assert load(Sample0.add(1, 2)) == {:ok, 3}
             end) =~ "do_add/2 is not defined with defd"
    end

    test "non-defd function in other module" do
      assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
               defmodule Other1 do
                 def do_add(a, b), do: a + b
               end

               defmodule Sample1 do
                 import Dx.Defd

                 defd add(a, b) do
                   Other1.do_add(a, b)
                 end
               end

               assert load(Sample1.add(1, 2)) == {:ok, 3}
             end) =~ "Other1.do_add/2 is not defined with defd"
    end

    test "non-defd function in other module wrapped in call/1" do
      refute ExUnit.CaptureIO.capture_io(:stderr, fn ->
               defmodule Other1 do
                 def do_add(a, b), do: a + b
               end

               defmodule Sample1 do
                 import Dx.Defd

                 defd add(a, b) do
                   call(Other1.do_add(a, b))
                 end
               end

               assert load(Sample1.add(1, 2)) == {:ok, 3}
             end) =~ "do_add/2 is not defined with defd"
    end

    test "undefined local function" do
      assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
               assert_raise CompileError,
                            ~r"#{location(+6)}: undefined function do_add/2",
                            fn ->
                              defmodule Sample2 do
                                import Dx.Defd

                                defd add(a, b) do
                                  do_add(a, b)
                                end
                              end
                            end
             end) == ""
    end

    test "undefined function in other module" do
      assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
               assert_raise CompileError,
                            ~r"#{location(+9)}: undefined function do_add/2 \(expected #{inspect(__MODULE__)}.Other3 to define such a function",
                            fn ->
                              defmodule Other3 do
                              end

                              defmodule Sample3 do
                                import Dx.Defd

                                defd add(a, b) do
                                  Other3.do_add(a, b)
                                end
                              end
                            end
             end) == ""
    end

    test "function in non-existing module" do
      assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
               assert_raise CompileError,
                            ~r"#{location(+6)}: undefined function do_add/2 \(module OtherSide does not exist\)",
                            fn ->
                              defmodule Sample4 do
                                import Dx.Defd

                                defd add(a, b) do
                                  OtherSide.do_add(a, b)
                                end
                              end
                            end
             end) == ""
    end
  end

  describe "data loading" do
    defd simple_assoc(list) do
      list.tasks
    end

    defd assoc_chain(task) do
      task.list.created_by
    end

    defd assoc_chain_field(task) do
      task.list.created_by.email
    end

    defd created_by(record) do
      record.created_by
    end

    defd assoc_chain_args(task) do
      simple_arg(created_by(task)).email
    end

    setup do
      user = create(User)
      list = create(List, %{created_by: user}) |> Repo.reload!()
      task = create(Task, %{list: list, created_by: user}) |> Repo.reload!()

      [user: user, list: list, task: task]
    end

    test "loads record.association if not loaded", %{
      list: %{id: list_id} = list,
      task: %{id: task_id},
      user: %{id: user_id}
    } do
      assert {:ok, [%Task{id: ^task_id, list_id: ^list_id, created_by_id: ^user_id}]} =
               load(simple_assoc(list))
    end

    test "loads association chain if not loaded", %{
      task: task,
      user: %{id: user_id}
    } do
      assert {:ok, %User{id: ^user_id}} = load(assoc_chain(task))
    end

    test "loads association chain field if not loaded", %{
      task: task,
      user: %{email: user_email}
    } do
      assert {:ok, ^user_email} = load(assoc_chain_field(task))
    end

    test "loads association chain as arguments", %{
      task: task,
      user: %{email: user_email}
    } do
      assert {:ok, ^user_email} = load(assoc_chain_args(task))
    end
  end
end
