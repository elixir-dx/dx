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

  describe "tasks active in time frame" do
    setup %{user: assistant} do
      admin = create(User, %{role: %{name: "Admin"}})

      period_end = DateTime.utc_now()
      period_start = DateTime.add(period_end, -30, :day)

      logs = [
        create(RoleAuditLog, %{
          event: :role_added,
          actor: admin,
          role: admin.role,
          assignee: assistant,
          inserted_at: period_start
        })
      ]

      [period_end: period_end, period_start: period_start, logs: logs]
    end

    test "tasks active in time frame", %{period_end: period_end, period_start: period_start} do
      defmodule TasksActiveTest do
        import Dx.Defd

        defd roles_active_during(active_from, active_to) do
          Enum.filter(RoleAuditLog, fn log ->
            DateTime.compare(log.inserted_at, active_to) == :lt and
              (DateTime.compare(log.inserted_at, active_from) == :gt or
                 (log.event == :role_added and
                    not removed_before_range_start?(log, active_from)))
          end)
        end

        defd removed_before_range_start?(log, active_from) do
          Enum.any?(RoleAuditLog, fn removal ->
            removal.event == :role_removed and
              removal.assignee_id == log.assignee_id and
              removal.role_id == log.role_id and
              DateTime.compare(removal.inserted_at, log.inserted_at) == :gt and
              DateTime.compare(removal.inserted_at, active_from) == :lt
          end)
        end
      end

      assert_queries([~r/"inserted_at" < '.+"inserted_at" > '.+exists\(/], fn ->
        assert [_] = TasksActiveTest.roles_active_during(period_start, period_end)
      end)
    end

    test "tasks active in time frame partial", %{list: list} do
      defmodule PartialTasksActiveTest do
        import Dx.Defd

        defd roles_active_during(active_from, active_to) do
          Enum.filter(RoleAuditLog, fn log ->
            DateTime.compare(log.inserted_at, active_to) == :lt and
              (DateTime.compare(log.inserted_at, active_from) == :gt or
                 (log.event == :role_added and
                    not removed_before_range_start?(log, active_from)))
          end)
        end

        defd removed_before_range_start?(log, active_from) do
          Enum.any?(RoleAuditLog, fn removal ->
            removal.event == :role_removed and
              removal.assignee_id == log.assignee_id and
              removal.role_id == log.role_id and
              non_dx(kannsenedwisse(removal.inserted_at, log.inserted_at)) and
              DateTime.compare(removal.inserted_at, active_from) == :lt
          end)
        end

        def kannsenedwisse(left, right) do
          DateTime.compare(left, right) == :gt
        end
      end

      assert_queries(
        [
          ~r/"inserted_at" < '.+"inserted_at" > '.+"event" = 'role_added'/,
          "FROM \"role_audit_logs\""
        ],
        fn ->
          PartialTasksActiveTest.roles_active_during(
            DateTime.add(DateTime.utc_now(), 30, :day),
            DateTime.utc_now()
          )
        end
      )
    end

    test "tasks active in time frame partial 2", %{list: list} do
      defmodule PartialTasksActiveTest2 do
        import Dx.Defd

        defd roles_active_during(active_from, active_to) do
          Enum.filter(RoleAuditLog, fn log ->
            DateTime.compare(log.inserted_at, active_to) == :lt and
              log.event == :role_added and
              not removed_before_range_start?(log, active_from)
          end)
        end

        defd removed_before_range_start?(log, active_from) do
          Enum.any?(RoleAuditLog, fn removal ->
            removal.event == :role_removed and
              removal.assignee_id == log.assignee_id and
              removal.role_id == log.role_id and
              non_dx(kannsenedwisse(removal.inserted_at, log.inserted_at)) and
              DateTime.compare(removal.inserted_at, active_from) == :lt
          end)
        end

        def kannsenedwisse(left, right) do
          DateTime.compare(left, right) == :gt
        end
      end

      assert_queries(
        [
          ~r/FROM "role_audit_logs".+"inserted_at" < '.+"event" = ANY\('{"role_added"}'\)/,
          "FROM \"role_audit_logs\""
        ],
        fn ->
          PartialTasksActiveTest2.roles_active_during(
            DateTime.add(DateTime.utc_now(), 30, :day),
            DateTime.utc_now()
          )
        end
      )
    end
  end
end
