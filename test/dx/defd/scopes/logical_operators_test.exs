defmodule Dx.Defd.Scopes.LogicalOperatorsTest do
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
        published?: true,
        created_by: user,
        from_template: list_template2
      })

    list3 =
      create(List, %{
        title: "Archived",
        hourly_points: 1.2,
        created_by: user2,
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
      lists: unload([list, list2, list3]),
      list: unload(list),
      list2: unload(list2),
      list3: unload(list3),
      list_template: unload(list_template),
      preloaded_task: task,
      task: unload(task)
    ]
  end

  describe "assoc is_nil chain" do
    test "works with &&", %{list: list, list2: list2, list3: list3} do
      refute_stderr(fn ->
        defmodule AssocNotNilAmpersandsTest do
          import Dx.Defd

          defd run(role_name) do
            Enum.filter(
              List,
              &(&1.created_by &&
                  &1.created_by.role &&
                  &1.created_by.role.name == role_name)
            )
          end
        end

        expected_query =
          ~r/FROM \"lists\" .+ JOIN \"users\" .+ JOIN \"roles\" .+ WHERE \(+NOT \(\w+\d\."created_by_id" IS NULL\) AND NOT \(\w+\d\."role_id" IS NULL\)/

        assert_queries([[expected_query, "\"name\" = 'Assistant'"]], fn ->
          assert load!(AssocNotNilAmpersandsTest.run("Assistant")) == [list, list2]
        end)

        assert_queries([[expected_query, "\"name\" = 'Admin'"]], fn ->
          assert load!(AssocNotNilAmpersandsTest.run("Admin")) == [list3]
        end)
      end)
    end

    test "works with and", %{list: list, list2: list2, list3: list3} do
      refute_stderr(fn ->
        defmodule AssocNotNilAndTest do
          import Dx.Defd

          defd run(role_name) do
            Enum.filter(
              List,
              &(not is_nil(&1.created_by) and
                  not is_nil(&1.created_by.role) and
                  &1.created_by.role.name == role_name)
            )
          end
        end

        expected_query =
          ~r/FROM \"lists\" .+ JOIN \"users\" .+ JOIN \"roles\" .+ WHERE \(+NOT \(\w+\d\."created_by_id" IS NULL\) AND NOT \(\w+\d\."role_id" IS NULL\)/

        assert_queries([[expected_query, "\"name\" = 'Assistant'"]], fn ->
          assert load!(AssocNotNilAndTest.run("Assistant")) == [list, list2]
        end)

        assert_queries([[expected_query, "\"name\" = 'Admin'"]], fn ->
          assert load!(AssocNotNilAndTest.run("Admin")) == [list3]
        end)
      end)
    end
  end

  describe "and/2" do
    test "filter twice", %{list: %{id: list_id}} do
      assert_queries([["\"title\" = 'Tasks'", "\"hourly_points\" = ANY('{1.0}')"]], fn ->
        refute_stderr(fn ->
          defmodule AndTest do
            import Dx.Defd

            defd run() do
              Enum.filter(
                List,
                &(&1.title == "Tasks" and
                    &1.hourly_points == 1.0)
              )
            end
          end

          assert [%List{title: "Tasks"}] = load!(AndTest.run())
        end)
      end)
    end

    test "filter partial condition", %{list: list} do
      assert_queries(["\"hourly_points\" = ANY('{0.2}')"], fn ->
        assert_stderr("not defined with defd", fn ->
          defmodule AndNonDefdTest do
            import Dx.Defd

            defd run() do
              Enum.filter(
                List,
                &(__MODULE__.title(&1) == "Tasks" and
                    &1.hourly_points == 0.2)
              )
            end

            def title(arg) do
              arg.title
            end
          end

          assert [] = load!(AndNonDefdTest.run())
        end)
      end)
    end
  end

  describe "&&/2" do
    test "filter twice", %{lists: lists} do
      assert_queries(
        [["NOT ", "\"title\" IS NULL)", " AND ", "NOT ", "\"hourly_points\" IS NULL)"]],
        fn ->
          refute_stderr(fn ->
            defmodule AmpersandsFilterTest do
              import Dx.Defd

              defd run() do
                Enum.filter(List, &(&1.title && &1.hourly_points))
              end
            end

            assert load!(AmpersandsFilterTest.run()) == lists
          end)
        end
      )
    end

    test "filter by boolean field", %{list2: list2} do
      assert_queries(
        [["\"published?\" = ANY('{TRUE}'))", " AND ", "NOT ", "\"hourly_points\" IS NULL)"]],
        fn ->
          refute_stderr(fn ->
            defmodule AmpersandsBooleanFieldTest do
              import Dx.Defd

              defd run() do
                Enum.filter(List, &(&1.published? && &1.hourly_points))
              end
            end

            assert load!(AmpersandsBooleanFieldTest.run()) == [list2]
          end)
        end
      )
    end

    test "filter partial condition", %{lists: lists} do
      assert_queries([["NOT ", "\"hourly_points\" IS NULL)"]], fn ->
        assert_stderr("not defined with defd", fn ->
          defmodule AmpersandsNonDefdTest do
            import Dx.Defd

            defd run() do
              Enum.filter(List, &(__MODULE__.title(&1) && &1.hourly_points))
            end

            def title(arg) do
              arg.title
            end
          end

          assert load!(AmpersandsNonDefdTest.run()) == lists
        end)
      end)
    end
  end
end
