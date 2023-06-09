defmodule Dx.Defd.CaseTest do
  use Dx.Test.DataCase, async: true

  import Dx.Defd

  defmacrop location(plus) do
    file = Path.relative_to_cwd(__CALLER__.file)
    quote do: "#{unquote(file)}:#{unquote(__CALLER__.line) + unquote(plus)}"
  end

  describe "data loading" do
    setup do
      user = create(User)
      list = create(List, %{created_by: user})
      task = create(Task, %{list: list, created_by: user})

      [
        user: user,
        preloaded_list: list,
        list: Repo.reload!(list),
        preloaded_task: task,
        task: Repo.reload!(task)
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

    test "matches tuple", %{list: list, user: %{id: user_id}} do
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
  end

  describe "compile error" do
    test "when matching a tuple" do
      assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
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
             end) == ""
    end
  end
end
