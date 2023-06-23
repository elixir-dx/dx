defmodule Dx.Defd.EnumTest do
  use Dx.Test.DefdCase, async: true

  setup do
    user = create(User, %{role: %{name: "Assistant"}})
    list = create(List, %{created_by: user})
    task = create(Task, %{list: list, created_by: user})

    [
      user: Repo.reload!(user),
      preloaded_user: user,
      preloaded_list: %{list | tasks: [task]},
      list: Repo.reload!(list),
      preloaded_task: task,
      task: Repo.reload!(task)
    ]
  end

  describe "map/2" do
    test "works with identity function", %{list: list, task: task} do
      defmodule MapIdentityTest do
        import Dx.Defd

        defd tasks(list) do
          Enum.map(list.tasks, fn task -> task end)
        end
      end

      assert load(MapIdentityTest.tasks(list)) == {:ok, [task]}
    end

    test "function calling other defd function", %{list: list, user: user} do
      defmodule MapInlineFunTest do
        import Dx.Defd

        defd tasks(list) do
          Enum.map(list.tasks, fn task -> email(task) end)
        end

        defd email(task) do
          task.created_by.email
        end
      end

      assert load(MapInlineFunTest.tasks(list)) == {:ok, [user.email]}
    end

    test "function calling non-defd function", %{list: list, user: user} do
      defmodule MapInlineExternalFunTest do
        import Dx.Defd

        defd tasks(list) do
          Enum.map(list.tasks, fn task -> call(email(task)) end)
        end

        def email(task) do
          task.created_by_id
        end
      end

      assert load(MapInlineExternalFunTest.tasks(list)) == {:ok, [user.id]}
    end

    test "works", %{list: list, task: task} do
      defmodule Map2Test do
        import Dx.Defd

        defd task_titles(list) do
          Enum.map(list.tasks, & &1.title)
        end
      end

      assert load(Map2Test.task_titles(list)) == {:ok, [task.title]}
    end

    test "loads association", %{list: list, task: task, user: user} do
      defmodule MapAssocTest do
        import Dx.Defd

        defd task_titles(list) do
          Enum.map(list.tasks, & &1.created_by.email)
        end
      end

      assert load(MapAssocTest.task_titles(list)) == {:ok, [user.email]}
    end

    test "Enum in fn", %{list: list, task: task, user: user} do
      defmodule EnumInFnTest do
        import Dx.Defd

        defd task_titles(list) do
          Enum.map([list], fn list ->
            Enum.map(list.tasks, & &1.created_by.email)
          end)
        end
      end

      assert load(EnumInFnTest.task_titles(list)) == {:ok, [[user.email]]}
    end
  end
end
