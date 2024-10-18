defmodule Dx.Defd.CaseTest do
  use Dx.Test.DefdCase, async: false

  describe "data loading" do
    setup do
      user = create(User, %{role: %{name: "Assistant"}})
      list = create(List, %{created_by: user})
      task = create(Task, %{list: list, created_by: user})

      [
        user: unload(user),
        preloaded_user: user,
        preloaded_list: %{list | tasks: [task]},
        list: unload(list),
        preloaded_task: task,
        task: unload(task)
      ]
    end

    test "matches field in association", %{list: list, user: %{id: user_id}} do
      defmodule AssocFieldTest do
        import Dx.Defd

        defd created_by_id(list) do
          case list do
            %{created_by: %{id: id}} -> id
            _other -> nil
          end
        end
      end

      assert load(AssocFieldTest.created_by_id(list)) == {:ok, user_id}
    end

    test "matches field in nested association", %{task: task, user: %{id: user_id}} do
      defmodule DeepAssocFieldTest do
        import Dx.Defd

        defd created_by_id(task) do
          case task do
            %{list: %{created_by: %{id: id}}} -> id
            _other -> nil
          end
        end
      end

      assert load(DeepAssocFieldTest.created_by_id(task)) == {:ok, user_id}
    end

    test "matches field in typed association", %{task: task, user: %{id: user_id}} do
      defmodule TypedAssocFieldTest do
        import Dx.Defd

        defd created_by_id(task) do
          case task do
            %Task{list: %List{created_by: %{id: id}}} -> id
            _other -> nil
          end
        end
      end

      assert load(TypedAssocFieldTest.created_by_id(task)) == {:ok, user_id}
    end

    test "matches entire associated record", %{list: list, user: %{id: user_id}} do
      defmodule FullAssocTest do
        import Dx.Defd

        defd created_by(list) do
          case list do
            %{created_by: user} -> user
            _other -> nil
          end
        end
      end

      assert {:ok, %{id: ^user_id}} = load(FullAssocTest.created_by(list))
    end

    test "matches variable with list of records", %{list: list, user: %{id: user_id}} do
      defmodule AssignedListCaseTest do
        import Dx.Defd

        defd created_by(list) do
          lists = [list]

          case lists do
            [%{created_by: user}] -> user
            _other -> nil
          end
        end
      end

      assert {:ok, %{id: ^user_id}} = load(AssignedListCaseTest.created_by(list))
    end

    test "matches direct list of records", %{list: list, user: %{id: user_id}} do
      defmodule DirectListCaseTest do
        import Dx.Defd

        defd created_by(list) do
          case [list] do
            [%{created_by: user}] -> user
            other -> other
          end
        end
      end

      assert {:ok, %{id: ^user_id}} = load(DirectListCaseTest.created_by(list))
    end

    test "matches variable with scope", %{user: %{id: user_id}} do
      defmodule AssignedScopeCaseTest do
        import Dx.Defd

        defd created_by() do
          lists = Dx.Scope.all(List)

          case lists do
            [%{created_by: user}] -> user
            _other -> nil
          end
        end
      end

      assert {:ok, %{id: ^user_id}} = load(AssignedScopeCaseTest.created_by())
    end

    test "matches deeply nested variable with scope", %{user: %{id: user_id}} do
      defmodule NestedAssignedScopeCaseTest do
        import Dx.Defd

        defd created_by() do
          lists = Dx.Scope.all(List)

          case [%{lists: {:ok, lists}}] do
            [%{lists: {:ok, [%{created_by: user}]}}] -> user
            _other -> nil
          end
        end
      end

      assert {:ok, %{id: ^user_id}} = load(NestedAssignedScopeCaseTest.created_by())
    end

    test "loads nested scope lazily", %{list: list} do
      defmodule NestedLazyScopeCaseTest do
        import Dx.Defd

        defd created_by(status) do
          arg = Dx.Scope.all(List)

          case {status, lists: {:ok, arg}} do
            {:ok, lists: {:ok, scope}} -> scope
            _other -> nil
          end
        end
      end

      assert_queries([""], fn ->
        assert load!(NestedLazyScopeCaseTest.created_by(:ok)) == [list]
      end)

      assert_queries([], fn ->
        assert load!(NestedLazyScopeCaseTest.created_by(:error)) == nil
      end)
    end

    test "loads nested scope in variable lazily", %{list: list} do
      defmodule NestedLazyVarScopeCaseTest do
        import Dx.Defd

        defd created_by(status) do
          arg = {status, lists: {:ok, Dx.Scope.all(List)}}

          case arg do
            {:ok, lists: {:ok, scope}} -> scope
            _other -> nil
          end
        end
      end

      assert_queries([""], fn ->
        assert load!(NestedLazyVarScopeCaseTest.created_by(:ok)) == [list]
      end)

      assert_queries([], fn ->
        assert load!(NestedLazyVarScopeCaseTest.created_by(:error)) == nil
      end)
    end

    test "loads scope in tuple lazily", %{list: list} do
      defmodule TupleLazyScopeCaseTest do
        import Dx.Defd

        defd created_by() do
          arg = Dx.Scope.all(List)

          case {:ok, arg} do
            {:ok, [list]} -> list
          end
        end
      end

      assert_queries([""], fn ->
        assert load!(TupleLazyScopeCaseTest.created_by()) == list
      end)
    end

    test "loads scope in list lazily", %{list: list} do
      defmodule ListLazyScopeCaseTest do
        import Dx.Defd

        defd created_by() do
          arg = Dx.Scope.all(List)

          case [:ok, arg] do
            [:ok, [list]] -> list
          end
        end
      end

      assert_queries([""], fn ->
        assert load!(ListLazyScopeCaseTest.created_by()) == list
      end)
    end

    test "loads deeply nested scope lazily", %{list: list} do
      defmodule NestedLazyScopeCaseTest2 do
        import Dx.Defd

        defd created_by(status) do
          arg = Dx.Scope.all(List)

          case [%{status: status, lists: {:ok, arg}}] do
            [%{status: :ok, lists: {:ok, lists}}] -> lists
            _other -> nil
          end
        end
      end

      assert_queries([""], fn ->
        assert load!(NestedLazyScopeCaseTest2.created_by(:ok)) == [list]
      end)

      assert_queries([], fn ->
        assert load!(NestedLazyScopeCaseTest2.created_by(:error)) == nil
      end)
    end

    test "caret", %{list: list} do
      defmodule CaretCaseTest do
        import Dx.Defd

        defd created_by(status, expected) do
          count = Enum.count(List)

          case [%{status: status, list: {:ok, expected}}] do
            [%{status: :ok, list: {:ok, ^count}}] -> :ok
            _other -> nil
          end
        end
      end

      assert_queries([""], fn ->
        assert load!(CaretCaseTest.created_by(:ok, 1)) == :ok
      end)

      assert_queries([""], fn ->
        assert load!(CaretCaseTest.created_by(:ok, 0)) == nil
      end)
    end

    test "caret 2", %{list: list} do
      defmodule CaretCaseTest2 do
        import Dx.Defd

        defd created_by(status, expected) do
          count = Enum.count(List)

          case [%{status: status, list: {:ok, count}}] do
            [%{status: :ok, list: {:ok, ^expected}}] -> :ok
            _other -> nil
          end
        end
      end

      assert_queries([""], fn ->
        assert load!(CaretCaseTest2.created_by(:ok, 1)) == :ok
      end)

      assert_queries([""], fn ->
        assert load!(CaretCaseTest2.created_by(:ok, 0)) == nil
      end)
    end

    test "nested caret", %{user: %{id: user_id}} do
      defmodule NestedCaretCaseTest do
        import Dx.Defd

        defd created_by(status, expected) do
          list = Enum.find(List, fn _ -> true end)

          case [%{status: status, list: {:ok, list}}] do
            [%{status: :ok, list: {:ok, %{created_by: %{id: ^expected}}}}] -> :ok
            _other -> nil
          end
        end
      end

      assert_queries(["FROM \"lists\"", "FROM \"users\""], fn ->
        assert load!(NestedCaretCaseTest.created_by(:ok, user_id)) == :ok
      end)

      assert_queries(["FROM \"lists\"", "FROM \"users\""], fn ->
        assert load!(NestedCaretCaseTest.created_by(:ok, 0)) == nil
      end)
    end

    test "assign", %{user: user = %{id: user_id}} do
      defmodule AssignCaseTest do
        import Dx.Defd

        defd created_by(status, expected) do
          list = Enum.find(List, fn _ -> true end)

          case [%{status: status, list: {:ok, list}}] do
            [%{status: :ok, list: {:ok, %{created_by: user = %{id: ^expected}}}}] -> user
            _other -> nil
          end
        end
      end

      assert_queries(["FROM \"lists\"", "FROM \"users\""], fn ->
        assert load!(AssignCaseTest.created_by(:ok, user_id)) == user
      end)

      assert_queries(["FROM \"lists\"", "FROM \"users\""], fn ->
        assert load!(AssignCaseTest.created_by(:ok, 0)) == nil
      end)
    end

    test "loads scope in map key", %{list: list} do
      defmodule MapKeyScopeCaseTest do
        import Dx.Defd

        defd created_by(status) do
          count = Enum.count(List)

          case [%{:status => status, 1 => :ok}] do
            [%{:status => :ok, ^count => :ok}] -> :ok
            _other -> nil
          end
        end
      end

      assert_queries(["SELECT count"], fn ->
        assert load!(MapKeyScopeCaseTest.created_by(:ok)) == :ok
      end)

      assert_queries(["SELECT count"], fn ->
        assert load!(MapKeyScopeCaseTest.created_by(:error)) == nil
      end)
    end

    test "loads data in scope in map key", %{list: list} do
      defmodule LoadMapKeyScopeCaseTest do
        import Dx.Defd

        defd created_by(status) do
          template = Enum.find(ListTemplate, fn _ -> true end)

          case [%{:status => status, template => :ok}] do
            [
              %{
                :status => :ok,
                %ListTemplate{
                  id: 1,
                  title: "Default",
                  hourly_points: 0.2,
                  lists: [],
                  __meta__: %Ecto.Schema.Metadata{
                    state: :loaded,
                    context: nil,
                    prefix: nil,
                    source: "list_templates",
                    schema: ListTemplate
                  }
                } => :ok
              }
            ] ->
              :ok

            other ->
              {:error, other}
          end
        end
      end

      assert_queries(["FROM \"list_templates\""], fn ->
        assert {:error, _} = load!(LoadMapKeyScopeCaseTest.created_by(:ok))
      end)

      create(ListTemplate, %{title: "Default", hourly_points: 0.2, id: 1})

      assert_queries(["FROM \"list_templates\"", "FROM \"lists\""], fn ->
        assert load!(LoadMapKeyScopeCaseTest.created_by(:ok)) == :ok
      end)

      assert_queries(["FROM \"list_templates\"", "FROM \"lists\""], fn ->
        assert {:error, _} = load!(LoadMapKeyScopeCaseTest.created_by(:error))
      end)
    end

    test "matches scope directly", %{user: %{id: user_id}} do
      defmodule DirectScopeCaseTest do
        import Dx.Defd

        defd created_by() do
          case Dx.Scope.all(List) do
            [%{created_by: user}] -> user
            _other -> nil
          end
        end
      end

      assert {:ok, %{id: ^user_id}} = load(DirectScopeCaseTest.created_by())
    end

    test "supports anonymous functions", %{
      list: list,
      preloaded_user: %{role: %{name: role_name}}
    } do
      defmodule InnerFnTest do
        import Dx.Defd

        defd indirect_enum_map(list) do
          case list do
            %List{created_by: user} ->
              non_dx(
                defp_enum_map(list.tasks, fn _task ->
                  user.role.name
                end)
              )
          end
        end

        defp defp_enum_map(enum, fun), do: Enum.map(enum, fun)
      end

      assert load(InnerFnTest.indirect_enum_map(list)) == {:ok, [role_name]}
    end

    test "nested cases", %{
      list: list,
      preloaded_user: %{role: %{name: role_name}}
    } do
      defmodule NestedTest do
        import Dx.Defd

        defd indirect_enum_map(list) do
          case list do
            %List{created_by: user} ->
              case user.role do
                %{name: _role_name} ->
                  non_dx(
                    defp_enum_map(list.tasks, fn _task ->
                      user.role.name
                    end)
                  )
              end
          end
        end

        defp defp_enum_map(enum, fun), do: Enum.map(enum, fun)
      end

      assert load(NestedTest.indirect_enum_map(list)) == {:ok, [role_name]}
    end

    test "nested cases calling defd functions", %{
      list: list,
      preloaded_user: %{role: %{name: role_name}}
    } do
      defmodule Nested2Test do
        import Dx.Defd

        defd user_role(user) do
          user.role
        end

        defd indirect_enum_map(list) do
          case list do
            %List{created_by: user} ->
              case user_role(user) do
                %{name: "Assistant"} ->
                  user_role(user).name
              end
          end
        end
      end

      assert load(Nested2Test.indirect_enum_map(list)) == {:ok, role_name}
    end

    test "matches list", %{list: list, user: %{id: user_id}} do
      defmodule ListTest do
        import Dx.Defd

        defd created_by(list, mode) do
          case [list, mode] do
            [%{created_by: user}, :record] -> user
            [%{created_by_id: user_id}, :id] -> user_id
            _other -> nil
          end
        end
      end

      assert {:ok, %{id: ^user_id}} = load(ListTest.created_by(list, :record))
      assert {:ok, ^user_id} = load(ListTest.created_by(list, :id))
    end

    test "matches simple list", %{list: list, user: %{id: user_id}} do
      defmodule SimpleListTest do
        import Dx.Defd

        defd created_by(arg) do
          case [nil] do
            [nil] -> arg
          end
        end
      end

      assert {:ok, :record} = load(SimpleListTest.created_by(:record))
    end

    test "matches empty list", %{list: list, user: %{id: user_id}} do
      defmodule EmptyListTest do
        import Dx.Defd

        defd created_by(arg) do
          case [] do
            [] -> arg
          end
        end
      end

      assert {:ok, :record} = load(EmptyListTest.created_by(:record))
    end

    test "matches 2-tuple", %{list: list, user: %{id: user_id}} do
      defmodule TupleTest do
        import Dx.Defd

        defd created_by(list, mode) do
          case {list, mode} do
            {%{created_by: user}, :record} -> user
            {%{created_by_id: user_id}, :id} -> user_id
            _other -> nil
          end
        end
      end

      assert {:ok, %{id: ^user_id}} = load(TupleTest.created_by(list, :record))
      assert {:ok, ^user_id} = load(TupleTest.created_by(list, :id))
    end

    test "matches 3-tuple", %{list: list, user: %{id: user_id}} do
      defmodule Tuple3Test do
        import Dx.Defd

        defd created_by(list, mode) do
          case {list, mode, nil} do
            {%{created_by: user}, :record, nil} -> user
            {%{created_by_id: user_id}, :id, nil} -> user_id
            _other -> nil
          end
        end
      end

      assert {:ok, %{id: ^user_id}} = load(Tuple3Test.created_by(list, :record))
      assert {:ok, ^user_id} = load(Tuple3Test.created_by(list, :id))
    end
  end

  describe "compile error" do
    test "on case without clauses" do
      refute_stderr(fn ->
        assert_raise CompileError,
                     ~r"#{location(+6)}: Invalid case syntax",
                     fn ->
                       defmodule TupleMatchTest do
                         import Dx.Defd

                         defd add(a) do
                           case(a)
                         end
                       end
                     end
      end)
    end
  end
end
