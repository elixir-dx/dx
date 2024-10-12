defmodule Dx.DefdTest do
  use Dx.Test.DefdCase, async: false

  describe "constants" do
    test "returns true" do
      defmodule BoolConstTest do
        import Dx.Defd

        defd bool_constant() do
          true
        end
      end

      assert load(BoolConstTest.bool_constant()) == {:ok, true}
    end

    test "emits compiler warning when called directly" do
      defmodule DirectCallTest do
        import Dx.Defd

        defd bool_constant() do
          true
        end
      end

      assert_stderr("Use Dx.Defd.load as entrypoint", fn ->
        DirectCallTest.bool_constant()
      end)
    end

    test "emits no compiler warning when def: :no_warn" do
      defmodule OptsDefTest do
        import Dx.Defd

        @dx def: :no_warn
        defd no_warn() do
          :ok
        end

        defd default() do
          :ok
        end

        @dx def: :original
        defd original() do
          :ok
        end
      end

      refute_stderr(fn ->
        OptsDefTest.no_warn()
      end)

      assert_stderr("Use Dx.Defd.load as entrypoint", fn ->
        OptsDefTest.default()
      end)

      refute_stderr(fn ->
        OptsDefTest.original()
      end)
    end
  end

  describe "simple arg" do
    test "returns arg" do
      defmodule SimpleArgTest do
        import Dx.Defd

        defd simple_arg(arg) do
          arg
        end
      end

      assert load(SimpleArgTest.simple_arg(1)) == {:ok, 1}
    end

    test "allows piping into load function" do
      defmodule PipeLoadTest do
        import Dx.Defd

        defd simple_arg(arg) do
          arg
        end
      end

      assert 1 |> PipeLoadTest.simple_arg() |> load() == {:ok, 1}
      assert 1 |> PipeLoadTest.simple_arg() |> load!() == 1
      assert 1 |> PipeLoadTest.simple_arg() |> get() == {:ok, 1}
      assert 1 |> PipeLoadTest.simple_arg() |> get!() == 1
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

      refute_stderr(fn ->
        load(One.fun2())
        load(One.fun3())
        load(One.fun4())
      end)
    end
  end

  describe "calling non-defd functions" do
    test "non-defd local function" do
      assert_stderr("do_add/2 is not defined with defd", fn ->
        defmodule Sample0 do
          import Dx.Defd

          defd add(a, b) do
            do_add(a, b)
          end

          defp do_add(a, b), do: a + b
        end

        assert load(Sample0.add(1, 2)) == {:ok, 3}
      end)
    end

    test "non-defd local function wrapped in non_dx/1" do
      refute_stderr("do_add/2 is not defined with defd", fn ->
        defmodule Sample0 do
          import Dx.Defd

          defd add(a, b) do
            non_dx(do_add(a, b))
          end

          defp do_add(a, b), do: a + b
        end

        assert load(Sample0.add(1, 2)) == {:ok, 3}
      end)
    end

    test "non-defd function in other module" do
      assert_stderr("Other1.do_add/2 is not defined with defd", fn ->
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
      end)
    end

    test "non-defd function in other module wrapped in non_dx/1" do
      refute ExUnit.CaptureIO.capture_io(:stderr, fn ->
               defmodule Other1 do
                 def do_add(a, b), do: a + b
               end

               defmodule Sample1 do
                 import Dx.Defd

                 defd add(a, b) do
                   non_dx(Other1.do_add(a, b))
                 end
               end

               assert load(Sample1.add(1, 2)) == {:ok, 3}
             end) =~ "do_add/2 is not defined with defd"
    end

    test "undefined local function" do
      assert_stderr("undefined function do_add\/2", fn ->
        assert_raise CompileError, ~r/cannot compile module Dx.DefdTest.Sample2/, fn ->
          defmodule Sample2 do
            import Dx.Defd

            defd add(a, b) do
              do_add(a, b)
            end
          end
        end
      end)
    end
  end

  describe "data loading" do
    setup context do
      user_attrs = context[:user] || %{}
      user = create(User, user_attrs)
      list = create(List, %{created_by: user})
      task = create(Task, %{list: list, created_by: user})

      [
        user: user,
        preloaded_list: list,
        list: unload(list),
        preloaded_task: task,
        task: unload(task)
      ]
    end

    test "loads record.association if not loaded", %{
      list: %{id: list_id} = list,
      task: %{id: task_id},
      user: %{id: user_id}
    } do
      defmodule SimpleAssocTest do
        import Dx.Defd

        defd simple_assoc(list) do
          list.tasks
        end
      end

      assert {:ok, [%Task{id: ^task_id, list_id: ^list_id, created_by_id: ^user_id}]} =
               load(SimpleAssocTest.simple_assoc(list))
    end

    test "Dx functions get, get!, load and load! work", %{
      list: %{id: list_id} = list,
      task: %{id: task_id},
      user: %{id: user_id}
    } do
      defmodule APIFunctionsTest do
        import Dx.Defd

        defd simple_assoc(list) do
          list.tasks
        end
      end

      assert {:ok, [%Task{id: ^task_id, list_id: ^list_id, created_by_id: ^user_id}]} =
               load(APIFunctionsTest.simple_assoc(list))

      assert [%Task{id: ^task_id, list_id: ^list_id, created_by_id: ^user_id}] =
               load!(APIFunctionsTest.simple_assoc(list))

      assert {:not_loaded, _data_reqs} = get(APIFunctionsTest.simple_assoc(list))

      assert_raise Dx.Error.NotLoaded, fn ->
        get!(APIFunctionsTest.simple_assoc(list))
      end
    end

    test "loads association chain if not loaded", %{
      task: task,
      user: %{id: user_id}
    } do
      defmodule AssocChainTest do
        import Dx.Defd

        defd assoc_chain(task) do
          task.list.created_by
        end
      end

      assert {:ok, %User{id: ^user_id}} = load(AssocChainTest.assoc_chain(task))
    end

    test "loads association chain field if not loaded", %{
      task: task,
      user: %{email: user_email}
    } do
      defmodule AssocChainFieldTest do
        import Dx.Defd

        defd assoc_chain_field(task) do
          task.list.created_by.email
        end
      end

      assert {:ok, ^user_email} = load(AssocChainFieldTest.assoc_chain_field(task))
    end

    test "loads association chain as arguments", %{
      task: task,
      user: %{email: user_email}
    } do
      defmodule AssocChainArgsTest do
        import Dx.Defd

        defd simple_arg(arg) do
          arg
        end

        defd created_by(record) do
          record.created_by
        end

        defd assoc_chain_args(task) do
          simple_arg(created_by(task)).email
        end
      end

      assert {:ok, ^user_email} = load(AssocChainArgsTest.assoc_chain_args(task))
    end

    test "prepends constant list element" do
      defmodule PrependListConstTest do
        import Dx.Defd

        defd run(head, tail) do
          [head | tail]
        end
      end

      assert load(PrependListConstTest.run(1, [2, 3])) == {:ok, [1, 2, 3]}
    end

    test "prepends multiple constant list elements" do
      defmodule PrependListMultiConstTest do
        import Dx.Defd

        defd run(head, mid, tail) do
          [head, mid | tail]
        end
      end

      assert load(PrependListMultiConstTest.run(1, 2, [3, 4])) == {:ok, [1, 2, 3, 4]}
    end

    test "prepends loaded list element", %{task: task, user: user} do
      defmodule PrependListLoadTest do
        import Dx.Defd

        defd run(task, tail) do
          [task.created_by.email | tail]
        end
      end

      assert load(PrependListLoadTest.run(task, [2, 3])) == {:ok, [user.email, 2, 3]}
    end

    test "prepends multiple loaded list elements", %{task: task, list: list, user: user} do
      defmodule PrependListMultiLoadTest do
        import Dx.Defd

        defd run(task, list, tail) do
          [task.created_by.email, list.created_by.email | tail]
        end
      end

      assert load(PrependListMultiLoadTest.run(task, list, [3, 4])) ==
               {:ok, [user.email, user.email, 3, 4]}
    end

    test "concats strings using <>", %{task: task, list: list, user: user} do
      defmodule ConcatStringsTest do
        import Dx.Defd

        defd run(task, list) do
          task.title <> task.created_by.email <> list.created_by.email
        end
      end

      assert load!(ConcatStringsTest.run(task, list)) == task.title <> user.email <> user.email
    end

    test "interpolates string", %{task: task, list: list, user: user} do
      defmodule InterpolatesStringsTest do
        import Dx.Defd

        defd run(task) do
          task_count = Enum.count(Task)
          "#{task.title} (#{task.created_by.email}, #{task_count}, #{Enum.count(List)})"
        end
      end

      assert load!(InterpolatesStringsTest.run(task)) == "#{task.title} (#{user.email}, 1, 1)"
    end

    test "KeyError on invalid key", %{
      list: list
    } do
      defmodule InvalidKeyTest do
        import Dx.Defd

        @dx def: :original
        defd invalid_key(list) do
          list.unknown
        end
      end

      assert_same_error(
        KeyError,
        location(-6),
        fn -> InvalidKeyTest.invalid_key(list) end,
        fn -> Dx.Defd.load(InvalidKeyTest.invalid_key(list)) end
      )
    end

    test "KeyError on invalid key from association", %{
      preloaded_list: list
    } do
      defmodule InvalidNestedKeyTest do
        import Dx.Defd

        @dx def: :original
        defd invalid_nested_key(list) do
          list.created_by.unknown
        end
      end

      assert_same_error(
        KeyError,
        location(-6),
        fn -> InvalidNestedKeyTest.invalid_nested_key(list) end,
        fn -> Dx.Defd.load(InvalidNestedKeyTest.invalid_nested_key(list)) end
      )
    end

    test "KeyError on invalid key from external map", %{
      list: list
    } do
      defmodule InvalidExternalKeyTest do
        import Dx.Defd

        def map() do
          %{}
        end

        @dx def: :original
        defd invalid_external_key() do
          non_dx(map()).unknown
        end
      end

      assert_same_error(
        KeyError,
        location(-6),
        fn -> InvalidExternalKeyTest.invalid_external_key() end,
        fn -> Dx.Defd.load(InvalidExternalKeyTest.invalid_external_key()) end
      )
    end

    test "ArgumentError on invalid typed argument", %{
      list: list
    } do
      defmodule InvalidCallTest do
        import Dx.Defd

        @dx def: :original
        defd invalid_arg(list) do
          non_dx(String.trim(list))
        end
      end

      assert_same_error(
        FunctionClauseError,
        location(-6),
        fn -> InvalidCallTest.invalid_arg(list) end,
        fn -> Dx.Defd.load(InvalidCallTest.invalid_arg(list)) end
      )
    end
  end
end
