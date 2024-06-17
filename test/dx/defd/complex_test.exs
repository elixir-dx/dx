defmodule Dx.Defd.ComplexTest do
  use Dx.Test.DefdCase, async: false

  setup do
    list_template = create(ListTemplate)
    user = create(User, %{role: %{name: "Assistant"}})
    list = create(List, %{created_by: user, from_template: list_template})
    task = create(Task, %{list: list, created_by: user})

    [
      user: unload(user),
      preloaded_user: user,
      preloaded_list: %{list | tasks: [task]},
      list: unload(list),
      list_template: unload(list_template),
      preloaded_task: task,
      task: unload(task)
    ]
  end

  test "list template efficiency", %{list_template: list_template} do
    refute_stderr(fn ->
      defmodule ComplexTest1 do
        import Dx.Defd

        defd run(list_templates) do
          list_templates
          |> Enum.map(&%{list_template: &1, score: template_efficiency_score(&1)})
          |> Enum.sort_by(& &1.score)
          |> Enum.take(5)
        end

        defd template_efficiency_score(list_template) do
          avg(list_template.lists, &list_completion_ratio/1)
        end

        defd list_completion_ratio(list) do
          Enum.count(list.tasks, &task_completed?/1) / length(list.tasks)
        end

        defd task_completed?(task) do
          not is_nil(task.completed_at)
        end

        defd avg([], _fun) do
          0
        end

        defd avg(enum, fun) do
          mapped = Enum.map(enum, fun)
          Enum.sum(mapped) * 100 / length(mapped)
        end
      end

      assert {:ok, [%{list_template: %ListTemplate{}, score: 0.0}]} =
               load(ComplexTest1.run([list_template]))
    end)
  end

  test "compiles multiple nested Enums on same level", %{
    list: list,
    preloaded_list: preloaded_list
  } do
    refute_stderr(fn ->
      defmodule NestedTest do
        import Dx.Defd

        defd run(list) do
          Enum.map(list.tasks, fn task ->
            archived =
              Enum.find(task.created_by.lists, fn list ->
                not is_nil(list.archived_at)
              end)

            populated =
              Enum.find(task.created_by.lists, fn list ->
                Enum.count(list.tasks) > 1
              end)

            archived || populated
          end)
        end

        defd swapped(list) do
          Enum.map(list.tasks, fn task ->
            populated =
              Enum.find(task.created_by.lists, fn list ->
                Enum.count(list.tasks) > 1
              end)

            archived =
              Enum.find(task.created_by.lists, fn list ->
                not is_nil(list.archived_at)
              end)

            archived || populated
          end)
        end
      end
    end)
  end
end
