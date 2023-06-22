defmodule Dx.Defd.ArgsTest do
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

        defd created_by_id(%{created_by: %{id: id}}) do
          id
        end

        defd created_by_id(_other) do
          nil
        end
      end

      assert load(AssocFieldTest.created_by_id(list)) == {:ok, user_id}
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
  end
end
