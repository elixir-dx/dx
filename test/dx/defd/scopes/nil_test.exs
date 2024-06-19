defmodule Dx.Defd.Scopes.NilTest do
  use Dx.Test.DefdCase, async: false

  setup do
    list_template = create(ListTemplate)
    list_template2 = create(ListTemplate)
    role = create(Role, %{name: "Assistant"})
    role2 = create(Role, %{name: "Admin"})
    user = create(User, %{role: role})
    user2 = create(User, %{role: role2})

    list =
      create(List, %{
        title: "Tasks",
        hourly_points: 1.0,
        created_by: user,
        from_template: list_template
      })

    list2 =
      create(List, %{
        title: "Irrelevant",
        hourly_points: 0.2,
        created_by: user,
        from_template: list_template2
      })

    list3 =
      create(List, %{
        title: "Archived",
        hourly_points: 1.2,
        created_by: user,
        archived_at: ~U[2024-02-24 02:34:56Z]
      })

    task = create(Task, %{list: list, created_by: user})

    [
      user: unload(user),
      user2: unload(user2),
      preloaded_user: user,
      preloaded_user2: user2,
      users: unload([user, user2]),
      role: unload(role),
      role2: unload(role2),
      preloaded_role: role,
      preloaded_role2: role2,
      roles: unload([role, role2]),
      preloaded_list: %{list | tasks: [task]},
      preloaded_list2: %{list2 | tasks: []},
      lists: unload([list, list2, list3]) |> dbg(),
      list: unload(list),
      list2: unload(list2),
      list3: unload(list3),
      list_template: unload(list_template),
      preloaded_task: task,
      task: unload(task)
    ]
  end

  test "field is_nil", %{list: list, list2: list2} do
    assert_queries([["FROM \"lists\"", "\"archived_at\" IS NULL"]], fn ->
      refute_stderr(fn ->
        defmodule NilFieldTest do
          import Dx.Defd

          defd run() do
            List
            |> Enum.filter(&is_nil(&1.archived_at))
          end
        end

        assert load!(NilFieldTest.run()) == [list, list2]
      end)
    end)
  end

  test "field is_nil when batched", %{users: users, list: list, list2: list2} do
    assert_queries([["FROM \"lists\"", "\"archived_at\" IS NULL"]], fn ->
      refute_stderr(fn ->
        defmodule NilBatchedFieldTest do
          import Dx.Defd

          defd run(users) do
            Enum.map(users, fn user ->
              List
              |> Enum.filter(&(&1.created_by_id == user.id))
              |> Enum.filter(&is_nil(&1.archived_at))
            end)
          end
        end

        assert load!(NilBatchedFieldTest.run(users)) == [[list, list2], []]
      end)
    end)
  end

  test "field with nil in batch",
       %{list_template: list_template, list: list, list3: list3} do
    refute_stderr(fn ->
      defmodule NilBatchFieldTest do
        import Dx.Defd

        defd run(template_id) do
          without_template = Enum.filter(List, &is_nil(&1.from_template_id))
          given_template = Enum.filter(List, &(&1.from_template_id == template_id))
          without_template ++ given_template
        end
      end

      result =
        assert_queries(
          [
            [
              "FROM \"lists\"",
              "\"from_template_id\" IS NULL) OR ",
              "\"from_template_id\" = ANY('{#{list_template.id}}')"
            ]
          ],
          fn ->
            load!(NilBatchFieldTest.run(list_template.id))
          end
        )

      assert result == [list3, list]
    end)
  end

  test "association is_nil", %{list3: list3} do
    assert_queries([["FROM \"lists\"", "\"from_template_id\" IS NULL"]], fn ->
      refute_stderr(fn ->
        defmodule NilAssocTest do
          import Dx.Defd

          defd run() do
            List
            |> Enum.filter(&is_nil(&1.from_template))
          end
        end

        assert load!(NilAssocTest.run()) == [list3]
      end)
    end)
  end

  test "association is_nil when batched", %{users: users, list3: list3} do
    assert_queries([["FROM \"lists\"", "\"from_template_id\" IS NULL"]], fn ->
      refute_stderr(fn ->
        defmodule NilBatchedAssocTest do
          import Dx.Defd

          defd run(users) do
            Enum.map(users, fn user ->
              List
              |> Enum.filter(&(&1.created_by_id == user.id))
              |> Enum.filter(&is_nil(&1.from_template))
            end)
          end
        end

        assert load!(NilBatchedAssocTest.run(users)) == [[list3], []]
      end)
    end)
  end

  test "association with nil in batch",
       %{list_template: list_template, list: list, list3: list3} do
    refute_stderr(fn ->
      defmodule NilBatchAssocTest do
        import Dx.Defd

        defd run(template) do
          without_template = Enum.filter(List, &is_nil(&1.from_template))
          given_template = Enum.filter(List, &(&1.from_template == template))
          without_template ++ given_template
        end
      end

      result =
        assert_queries(
          [
            [
              "FROM \"lists\"",
              "\"from_template_id\" IS NULL) OR ",
              "\"from_template_id\" = ANY('{#{list_template.id}}')"
            ]
          ],
          fn ->
            load!(NilBatchAssocTest.run(list_template))
          end
        )

      assert result == [list3, list]
    end)
  end

  test "nested association is_nil or struct", %{role: role, lists: lists} do
    refute_stderr(fn ->
      defmodule NilNestedAssocTest do
        import Dx.Defd

        defd run(role) do
          without_role = Enum.filter(List, &is_nil(&1.created_by.role))
          given_role = Enum.filter(List, &(&1.created_by.role == role))
          without_role ++ given_role
        end
      end

      result =
        assert_queries(
          [
            ["FROM \"lists\"", "\"role_id\" IS NULL)"],
            ["FROM \"lists\"", "\"role_id\" = #{role.id}"]
          ],
          fn ->
            load!(NilNestedAssocTest.run(role))
          end
        )

      assert result == lists
    end)
  end
end
