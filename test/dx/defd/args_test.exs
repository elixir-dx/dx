defmodule Dx.Defd.ArgsTest do
  use Dx.Test.DefdCase, async: false

  describe "guards" do
    test "work" do
      defmodule SimpleGuardTest do
        import Dx.Defd

        defd run_case(arg) do
          case arg do
            x when is_integer(x) -> x
            _other -> nil
          end
        end

        defd run(arg) when is_integer(arg) do
          arg
        end

        defd run(_other) do
          nil
        end
      end

      assert load(SimpleGuardTest.run_case(2)) == {:ok, 2}
      assert load(SimpleGuardTest.run(2)) == {:ok, 2}

      assert load(SimpleGuardTest.run_case("2")) == {:ok, nil}
      assert load(SimpleGuardTest.run("2")) == {:ok, nil}
    end

    test "load data via dot access" do
      defmodule AccessGuardTest do
        import Dx.Defd

        defd run_case(list) do
          case list do
            x when x.created_by.first_name == "Joey" -> x
            _other -> nil
          end
        end

        @dx def: :original
        defd run(list) when list.created_by.first_name == "Joey" do
          list
        end

        defd run(_other) do
          nil
        end
      end

      list = create(List, %{created_by: %{first_name: "Joey"}})
      assert AccessGuardTest.run(list) == list
      assert load(AccessGuardTest.run_case(unload(list))) == {:ok, list}
      assert load(AccessGuardTest.run(unload(list))) == {:ok, list}

      list = create(List, %{created_by: %{first_name: "Ska"}})
      assert load(AccessGuardTest.run_case(unload(list))) == {:ok, nil}
      assert load(AccessGuardTest.run(unload(list))) == {:ok, nil}
    end

    test "load data via custom guard" do
      defmodule CustomGuardTest.Guards do
        defguard is_joey(x) when x.created_by.first_name == "Joey"
      end

      defmodule CustomGuardTest do
        import Dx.Defd
        import CustomGuardTest.Guards

        defd run_case(list) do
          case list do
            x when is_joey(x) -> x
            _other -> nil
          end
        end

        @dx def: :original
        defd run(list) when is_joey(list) do
          list
        end

        defd run(_other) do
          nil
        end
      end

      list = create(List, %{created_by: %{first_name: "Joey"}})
      assert load(CustomGuardTest.run_case(unload(list))) == {:ok, list}
      assert CustomGuardTest.run(list) == list
      assert load(CustomGuardTest.run(unload(list))) == {:ok, list}

      list = create(List, %{created_by: %{first_name: "Ska"}})
      assert load(CustomGuardTest.run_case(unload(list))) == {:ok, nil}
      assert load(CustomGuardTest.run(unload(list))) == {:ok, nil}
    end

    test "work with scopes" do
      defmodule ScopeGuardTest do
        import Dx.Defd

        defd run_case() do
          case Enum.count(User) do
            count when not is_nil(count) and count > 0 -> count
            _other -> nil
          end
        end

        defd run() do
          Enum.count(User)
          |> do_run()
        end

        defd do_run(count) when count > 0 do
          count
        end

        defd do_run(_other) do
          nil
        end
      end

      assert load(ScopeGuardTest.run_case()) == {:ok, nil}
      assert load(ScopeGuardTest.run()) == {:ok, nil}

      create(User)
      assert load(ScopeGuardTest.run_case()) == {:ok, 1}
      assert load(ScopeGuardTest.run()) == {:ok, 1}
    end

    test "work with patterns" do
      defmodule PatternGuardTest do
        import Dx.Defd

        defd run_case() do
          case Enum.find(User, &(&1.first_name == "Joey")) do
            %{first_name: "Joey"} = user -> user.first_name
            _other -> nil
          end
        end

        defd run() do
          Enum.find(User, &(&1.first_name == "Joey"))
          |> do_run()
        end

        defd do_run(%{first_name: "Joey"} = user) do
          user.first_name
        end

        defd do_run(_other) do
          nil
        end
      end

      assert load(PatternGuardTest.run_case()) == {:ok, nil}
      assert load(PatternGuardTest.run()) == {:ok, nil}

      create(User, %{first_name: "Joey"})
      assert load(PatternGuardTest.run_case()) == {:ok, "Joey"}
      assert load(PatternGuardTest.run()) == {:ok, "Joey"}
    end

    test "work with functions" do
      defmodule FunGuardTest do
        import Dx.Defd

        defd run_case() do
          case &is_nil/1 do
            x when is_function(x, 2) -> :double
            x when is_function(x) -> :fun
            _other -> nil
          end
        end

        defd run() do
          (&is_nil/1)
          |> do_run()
        end

        defd run_double() do
          fn x, y -> x + y + 1 end
          |> do_run()
        end

        defd do_run(x) when is_function(x, 2) do
          :double
        end

        defd do_run(x) when is_function(x) do
          :fun
        end

        defd do_run(_other) do
          nil
        end
      end

      assert load(FunGuardTest.run_case()) == {:ok, :fun}
      assert load(FunGuardTest.run()) == {:ok, :fun}
      assert load(FunGuardTest.run_double()) == {:ok, :double}
    end

    test "work with in" do
      defmodule GuardInTest do
        import Dx.Defd

        defd run_case(input, mode) do
          case {input, mode} do
            {_input, mode} when mode in [:in, :out] ->
              :double

            _other ->
              nil
          end
        end

        defd run(input, mode) when mode in [:in, :out] do
          {input, mode}
        end
      end

      assert load(GuardInTest.run_case(nil, :in)) == {:ok, :double}
      assert load(GuardInTest.run_case(nil, :reverse)) == {:ok, nil}
      assert load(GuardInTest.run(nil, :in)) == {:ok, {nil, :in}}
    end
  end

  describe "data loading" do
    setup do
      user = create(User)
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

    test "matches field in association", %{list: list, user: %{id: user_id}} do
      defmodule AssocFieldTest do
        import Dx.Defd

        defd created_by_id(%{created_by: %{id: id}}) do
          id
        end

        defd created_by_id(_other) do
          nil
        end
      end

      assert load(AssocFieldTest.created_by_id(list)) == {:ok, user_id}
    end

    test "single clause matches field in association", %{list: list, user: %{id: user_id}} do
      defmodule AssocFieldSingleTest do
        import Dx.Defd

        defd created_by_id(%{created_by: %{id: id}}) do
          id
        end
      end

      assert load(AssocFieldSingleTest.created_by_id(list)) == {:ok, user_id}
    end

    test "matches field in nested association", %{task: task, user: %{id: user_id}} do
      defmodule DeepAssocFieldTest do
        import Dx.Defd

        defd created_by_id(%{list: %{created_by: %{id: id}}}) do
          id
        end

        defd created_by_id(_other) do
          nil
        end
      end

      assert load(DeepAssocFieldTest.created_by_id(task)) == {:ok, user_id}
    end

    test "matches field in typed association", %{task: task, user: %{id: user_id}} do
      defmodule TypedAssocFieldTest do
        import Dx.Defd

        defd created_by_id(%Task{list: %List{created_by: %{id: id}}}) do
          id
        end

        defd created_by_id(_other) do
          nil
        end
      end

      assert load(TypedAssocFieldTest.created_by_id(task)) == {:ok, user_id}
    end

    test "ignores invalid field in non-matching clause", %{task: task, user: %{id: user_id}} do
      defmodule InvalidAssocFieldTest do
        import Dx.Defd

        defd created_by_id(%Task{list: %List{created_by: %{id: id}}}) do
          id
        end

        defd created_by_id(%{unknown: %List{created_by: %{id: id}}}) do
          id
        end

        defd created_by_id(_other) do
          nil
        end
      end

      assert load(InvalidAssocFieldTest.created_by_id(task)) == {:ok, user_id}
    end

    test "matches entire associated record", %{list: list, user: %{id: user_id}} do
      defmodule FullAssocTest do
        import Dx.Defd

        defd created_by(%{created_by: user}) do
          user
        end

        defd created_by(_other) do
          nil
        end
      end

      assert {:ok, %{id: ^user_id}} = load(FullAssocTest.created_by(list))
    end

    test "handles default arguments" do
      defmodule DefaultArgs do
        import Dx.Defd

        defd(defargs(a, b \\ 1, c \\ :record))

        defd defargs(0, 1, 2) do
          :hit
        end

        defd defargs(0, 1, c) do
          c
        end

        defd defargs(a, 1, _c) do
          a
        end
      end

      defmodule CallingDefaultArgs do
        import Dx.Defd

        defd call_defargs0() do
          DefaultArgs.defargs(:first)
        end

        defd call_defargs1() do
          DefaultArgs.defargs(:first, 1)
        end

        defd call_defargs2() do
          DefaultArgs.defargs(:first, 1, 2)
        end

        defd call_defargs3() do
          DefaultArgs.defargs(0, 1, :third)
        end

        defd call_defargs_error() do
          DefaultArgs.defargs(:first, :second, :third)
        end
      end

      assert load(DefaultArgs.defargs(0, 1, 2)) == {:ok, :hit}
      assert load(CallingDefaultArgs.call_defargs0()) == {:ok, :first}
      assert load(CallingDefaultArgs.call_defargs1()) == {:ok, :first}
      assert load(CallingDefaultArgs.call_defargs2()) == {:ok, :first}
      assert load(CallingDefaultArgs.call_defargs3()) == {:ok, :third}

      assert_raise CaseClauseError, fn ->
        load(CallingDefaultArgs.call_defargs_error())
      end
    end

    test "raises correct error when one function clause doesn't match" do
      defmodule ClauseErrorTest do
        import Dx.Defd

        @dx def: :original
        defd created_by_id(%User{} = user) do
          user.created_by.id
        end
      end

      assert_same_error(
        FunctionClauseError,
        location(-7),
        fn -> ClauseErrorTest.created_by_id(nil) end,
        fn ->
          load(ClauseErrorTest.created_by_id(nil))
        end
      )
    end

    @tag :skip
    test "raises correct error when no function clause matches" do
      defmodule ClausesErrorTest do
        import Dx.Defd

        @dx def: :original
        defd created_by_id(%{created_by: %{id: id}}) do
          id
        end

        defd created_by_id(%{created_by: %{name: "Herbo"}}) do
          nil
        end
      end

      assert_same_error(
        FunctionClauseError,
        location(-7),
        fn -> ClausesErrorTest.created_by_id(nil) end,
        fn ->
          load(ClausesErrorTest.created_by_id(nil))
        end
      )
    end
  end
end
