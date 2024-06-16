defmodule Dx.Defd.ScopeTest do
  use Dx.Test.DefdCase, async: false

  setup do
    list_template = create(ListTemplate)
    user = create(User, %{role: %{name: "Assistant"}})

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
        from_template: list_template
      })

    task = create(Task, %{list: list, created_by: user})

    [
      user: unload(user),
      preloaded_user: user,
      preloaded_list: %{list | tasks: [task]},
      preloaded_list2: %{list2 | tasks: []},
      lists: [unload(list), unload(list2)],
      list: unload(list),
      list2: unload(list2),
      list_template: unload(list_template),
      preloaded_task: task,
      task: unload(task)
    ]
  end

  test "load all", %{lists: lists} do
    assert_queries(["FROM \"lists\""], fn ->
      # refute_stderr(fn ->
      defmodule ScopeAllTest do
        import Dx.Defd

        defd run() do
          Dx.Scope.all(List)
        end
      end

      assert load!(ScopeAllTest.run()) == lists
      # end)
    end)
  end

  test "return nested scope", %{lists: lists} do
    assert_queries(["FROM \"lists\""], fn ->
      # refute_stderr(fn ->
      defmodule ReturnNestedScopeTest do
        import Dx.Defd

        defd run() do
          {:ok, [result: %{nested: Dx.Scope.all(List)}]}
        end
      end

      assert load!(ReturnNestedScopeTest.run()) == {:ok, [result: %{nested: lists}]}
      # end)
    end)
  end

  test "return nested fn without loaders", %{lists: lists} do
    assert_queries([], fn ->
      refute_stderr(fn ->
        defmodule ReturnNestedOkFnTest do
          import Dx.Defd

          defd run(arg) do
            {:ok, [result: %{nested: fn -> arg end}]}
          end
        end

        assert {:ok, [result: %{nested: fun}]} = load!(ReturnNestedOkFnTest.run("Hi!"))
        assert is_function(fun, 0)
        assert fun.() == "Hi!"
      end)
    end)
  end

  test "return nested fn with loaders", %{task: task, preloaded_task: preloaded_task} do
    assert_queries(["FROM \"users\""], fn ->
      refute_stderr(fn ->
        defmodule ReturnNestedLoadableFnTest do
          import Dx.Defd

          defd run(task) do
            {:ok, [result: %{nested: fn -> task.created_by.first_name end}]}
          end
        end

        assert {:ok, [result: %{nested: fun}]} = load!(ReturnNestedLoadableFnTest.run(task))
        assert is_function(fun, 0)
        assert fun.() == preloaded_task.created_by.first_name
      end)
    end)
  end

  test "return nested fn with externals+loaders", %{task: task, preloaded_task: preloaded_task} do
    assert_queries(["FROM \"users\""], fn ->
      refute_stderr(fn ->
        defmodule ReturnNestedExternalLoadableFnTest do
          import Dx.Defd

          defd run(task) do
            {:ok, [result: %{nested: fn -> non_dx(first_name(task.created_by)) end}]}
          end

          defp first_name(user) do
            user.first_name
          end
        end

        assert {:ok, [result: %{nested: fun}]} =
                 load!(ReturnNestedExternalLoadableFnTest.run(task))

        assert is_function(fun, 0)
        assert fun.() == preloaded_task.created_by.first_name
      end)
    end)
  end

  test "list map", %{user: user} do
    assert_queries(["FROM \"lists\"", "FROM \"users\""], fn ->
      refute_stderr(fn ->
        defmodule MapTest do
          import Dx.Defd

          defd run() do
            Enum.map(List, & &1.created_by)
          end
        end

        assert [^user, ^user] = load!(MapTest.run())
      end)
    end)
  end

  test "list filter", %{list: list, lists: lists} do
    assert_queries(["\"title\" = ANY('{\"Tasks\"}')"], fn ->
      refute_stderr(fn ->
        defmodule FilterTest do
          import Dx.Defd

          defd run(lists) do
            Enum.filter(lists, &(&1.title == "Tasks"))
          end
        end

        assert [^list] = load!(FilterTest.run(List))
        assert [^list] = load!(FilterTest.run(lists))
      end)
    end)
  end

  test "list filter with function reference", %{list: list, lists: lists} do
    refute_stderr(fn ->
      defmodule FilterFunRefTest do
        import Dx.Defd

        defd run(lists) do
          Enum.filter(lists, &fun/1)
        end

        defd run2(lists) do
          Enum.filter(lists, &__MODULE__.fun/1)
        end

        defd fun(list) do
          list.title == "Tasks"
        end
      end

      assert_queries(["\"title\" = ANY('{\"Tasks\"}')"], fn ->
        assert [^list] = load!(FilterFunRefTest.run(List))
      end)

      assert_queries([], fn ->
        assert [^list] = load!(FilterFunRefTest.run(lists))
      end)

      assert_queries(["\"title\" = ANY('{\"Tasks\"}')"], fn ->
        assert [^list] = load!(FilterFunRefTest.run2(List))
      end)

      assert_queries([], fn ->
        assert [^list] = load!(FilterFunRefTest.run2(lists))
      end)
    end)
  end

  test "filter twice", %{list: %{id: list_id}} do
    assert_queries([["\"title\" = 'Tasks'", "\"hourly_points\" = ANY('{1.0}')"]], fn ->
      refute_stderr(fn ->
        defmodule ScopeTest2 do
          import Dx.Defd

          defd run() do
            Enum.filter(Enum.filter(List, &(&1.title == "Tasks")), &(&1.hourly_points == 1.0))
          end
        end

        assert [%List{title: "Tasks"}] = load!(ScopeTest2.run())
      end)
    end)
  end

  test "all lists filter map", %{user: user} do
    assert_queries(["\"title\" = ANY('{\"Tasks\"}')", "FROM \"users\""], fn ->
      refute_stderr(fn ->
        defmodule AllFilterMapTest do
          import Dx.Defd

          defd run() do
            Enum.map(Enum.filter(List, &(&1.title == "Tasks")), & &1.created_by)
          end
        end

        assert [^user] = load!(AllFilterMapTest.run())
      end)
    end)
  end

  test "list filter map", %{user: user, lists: lists} do
    refute_stderr(fn ->
      defmodule FilterMapTest do
        import Dx.Defd

        defd run(lists) do
          Enum.map(Enum.filter(lists, &(&1.title == "Tasks")), & &1.created_by)
        end
      end

      assert_queries(["\"title\" = ANY('{\"Tasks\"}')", "FROM \"users\""], fn ->
        assert [^user] = load!(FilterMapTest.run(List))
      end)

      assert_queries(["FROM \"users\""], fn ->
        assert [^user] = load!(FilterMapTest.run(lists))
      end)
    end)
  end

  test "count lists" do
    assert_queries(["SELECT count(*) FROM \"lists\""], fn ->
      refute_stderr(fn ->
        defmodule CountListsTest do
          import Dx.Defd

          defd run() do
            Enum.count(List)
          end
        end

        assert {:ok, 2} = load(CountListsTest.run())
      end)
    end)
  end

  test "count empty table" do
    assert_queries(["SELECT count(*) FROM \"list_calendar_overrides\""], fn ->
      refute_stderr(fn ->
        defmodule CountZeroTest do
          import Dx.Defd

          defd run() do
            Enum.count(ListCalendarOverride)
          end
        end

        assert {:ok, 0} = load(CountZeroTest.run())
      end)
    end)
  end

  test "filter count lists" do
    assert_queries(
      ["SELECT count(*), l0.\"title\" FROM \"lists\" AS l0 GROUP BY l0.\"title\""],
      fn ->
        refute_stderr(fn ->
          defmodule FilterCountListsTest do
            import Dx.Defd

            defd run() do
              Enum.count(Enum.filter(List, &(&1.title == "Tasks")))
            end
          end

          assert {:ok, 1} = load(FilterCountListsTest.run())
        end)
      end
    )
  end

  test "filter count empty table" do
    assert_queries(
      [
        "SELECT count(*), l0.\"comment\" FROM \"list_calendar_overrides\" AS l0 GROUP BY l0.\"comment\""
      ],
      fn ->
        refute_stderr(fn ->
          defmodule FilterCountZeroTest do
            import Dx.Defd

            defd run() do
              Enum.count(Enum.filter(ListCalendarOverride, &(&1.comment == "Holiday")))
            end
          end

          assert {:ok, 0} = load(FilterCountZeroTest.run())
        end)
      end
    )
  end

  test "filter empty lists", %{list: list} do
    assert_queries([["(SELECT count(*) FROM \"tasks\"", " = 1"]], fn ->
      refute_stderr(fn ->
        defmodule FilterEmptyTest do
          import Dx.Defd

          defd run() do
            Enum.filter(List, &(Enum.count(&1.tasks) == 1))
          end
        end

        assert [^list] = load!(FilterEmptyTest.run())
      end)
    end)
  end

  test "filter comparing two fields", %{list: list} do
    assert_queries(
      [~s{WHERE (l0."archived_at" = l0."inserted_at")}],
      fn ->
        refute_stderr(fn ->
          defmodule FilterEqFieldsTest do
            import Dx.Defd

            defd run() do
              Enum.filter(List, &(&1.archived_at == &1.inserted_at))
            end
          end

          assert [] = load!(FilterEqFieldsTest.run())
        end)
      end
    )
  end

  test "filter comparing association field", %{list: list} do
    assert_queries(
      [~r/FROM \"lists\" .+ JOIN \"list_templates\" .+ WHERE \(\w\d\."title" = \w\d\."title"\)/],
      fn ->
        refute_stderr(fn ->
          defmodule FilterEqAssocFieldTest do
            import Dx.Defd

            defd run() do
              Enum.filter(List, &(&1.title == &1.from_template.title))
            end
          end

          assert [] = load!(FilterEqAssocFieldTest.run())
        end)
      end
    )
  end

  test "filter using other scope", %{list: list} do
    assert_queries(
      [~r/\(SELECT count\(\*\) FROM "tasks" .*\(SELECT count\(\*\) FROM "tasks"/],
      fn ->
        refute_stderr(fn ->
          defmodule FilterScopeResultTest do
            import Dx.Defd

            defd run() do
              task_count = Enum.count(Task)

              Enum.filter(List, &(Enum.count(&1.tasks) == task_count))
            end
          end

          assert [^list] = load!(FilterScopeResultTest.run())
        end)
      end
    )
  end

  test "filter using filter+count in condition", %{list: list} do
    assert_queries([~r/FROM "lists" AS \w+ WHERE .*\(SELECT count\(\*\) FROM "tasks"/], fn ->
      refute_stderr(fn ->
        defmodule FilterCountFilterTest do
          import Dx.Defd

          defd run() do
            Enum.filter(
              List,
              fn list ->
                Enum.count(Enum.filter(list.tasks, &(&1.title == "TODO"))) ==
                  1
              end
            )
          end
        end

        load!(FilterCountFilterTest.run())
      end)
    end)
  end

  test "filter using other scope with associations", %{list: list} do
    assert_queries(
      [~r/\(SELECT count\(\*\) FROM "tasks" .*\(SELECT count\(\*\) FROM "tasks"/],
      fn ->
        refute_stderr(fn ->
          defmodule FilterScopeAssocResultTest do
            import Dx.Defd

            defd run() do
              task_count = Enum.count(Task)

              Enum.filter(
                List,
                fn list ->
                  Enum.count(Enum.filter(list.tasks, &(&1.title == "TODO"))) ==
                    task_count
                end
              )
            end
          end

          load!(FilterScopeAssocResultTest.run())
        end)
      end
    )
  end

  test "passing in other scope", %{preloaded_task: preloaded_task} do
    assert_queries(["FROM \"tasks\"", "FROM \"users\""], fn ->
      refute_stderr(fn ->
        defmodule PassInScopeTest do
          import Dx.Defd

          defd run() do
            todos = Enum.filter(Task, &(&1.title == "My Task"))
            map_creator_names(todos)
          end

          defd map_creator_names(tasks) do
            Enum.map(tasks, & &1.created_by.first_name)
          end
        end

        assert load!(PassInScopeTest.run()) == [preloaded_task.created_by.first_name]
      end)
    end)
  end

  test "passing in scope to external function", %{task: task} do
    assert_queries(["FROM \"tasks\""], fn ->
      refute_stderr(fn ->
        defmodule PassScopeToExternalTest do
          import Dx.Defd

          defd run() do
            todos = Enum.filter(Task, &(&1.title == "My Task"))
            non_dx(task_descs(todos))
          end

          defp task_descs(tasks) do
            Enum.map(tasks, & &1.desc)
          end
        end

        assert load!(PassScopeToExternalTest.run()) == [task.desc]
      end)
    end)
  end

  test "passing in nested scope to external function", %{task: task} do
    assert_queries(["FROM \"tasks\""], fn ->
      refute_stderr(fn ->
        defmodule PassNestedScopeToExternalTest do
          import Dx.Defd

          defd run() do
            todos = Enum.filter(Task, &(&1.title == "My Task"))
            non_dx(task_descs(%{todos: {:nested, todos}}))
          end

          defp task_descs(%{todos: {:nested, tasks}}) do
            Enum.map(tasks, & &1.desc)
          end
        end

        assert load!(PassNestedScopeToExternalTest.run()) == [task.desc]
      end)
    end)
  end

  test "filter using defd condition", %{list: list} do
    assert_queries([["\"title\" = 'Tasks'", "\"hourly_points\" = ANY('{1.0}')"]], fn ->
      refute_stderr(fn ->
        defmodule FilterDefdTest do
          import Dx.Defd

          defd run() do
            Enum.filter(
              Enum.filter(List, &(title(&1) == "Tasks")),
              &(&1.hourly_points == 1.0)
            )
          end

          defd title(arg) do
            arg.title
          end
        end

        assert [^list] = load!(FilterDefdTest.run())
      end)
    end)
  end

  test "filter using combined defd condition", %{list: list} do
    assert_queries([["\"title\" = ANY('{\"Tasks\"}')", "(SELECT count("]], fn ->
      refute_stderr(fn ->
        defmodule FilterComboDefdTest do
          import Dx.Defd

          defd run() do
            Enum.filter(
              Enum.filter(List, &(title(&1) == "Tasks")),
              &(task_count(&1) == 1)
            )
          end

          defd title(list) do
            list.title
          end

          defd task_count(list) do
            Enum.count(list.tasks)
          end
        end

        assert [^list] = load!(FilterComboDefdTest.run())
      end)
    end)
  end

  test "filter by defd condition", %{list: list} do
    refute_stderr(fn ->
      defmodule FilterDefdRefTest do
        import Dx.Defd

        defd run() do
          Enum.filter(
            Enum.filter(List, &title/1),
            &(&1.hourly_points == 1.0)
          )
        end

        defd run2() do
          Enum.filter(
            Enum.filter(List, &__MODULE__.title/1),
            &(&1.hourly_points == 1.0)
          )
        end

        defd title(list) do
          list.title == "Tasks"
        end
      end

      assert_queries([["\"hourly_points\" = ANY('{1.0}')", "\"title\" = 'Tasks'"]], fn ->
        assert [^list] = load!(FilterDefdRefTest.run())
      end)

      assert_queries([["\"hourly_points\" = ANY('{1.0}')", "\"title\" = 'Tasks'"]], fn ->
        assert [^list] = load!(FilterDefdRefTest.run2())
      end)
    end)
  end

  test "filter using pseudo-remote defd function", %{list: list} do
    assert_queries([["\"hourly_points\" = ANY('{1.0}')", "\"title\" = 'Tasks'"]], fn ->
      refute_stderr(fn ->
        defmodule FilterModDefdTest do
          import Dx.Defd

          defd run() do
            Enum.filter(
              Enum.filter(List, &(__MODULE__.title(&1) == "Tasks")),
              &(&1.hourly_points == 1.0)
            )
          end

          defd title(arg) do
            arg.title
          end
        end

        assert [^list] = load!(FilterModDefdTest.run())
      end)
    end)
  end

  test "filter partial condition 1", %{list: list} do
    assert_queries(["\"hourly_points\" = ANY('{0.2}')"], fn ->
      assert_stderr("not defined with defd", fn ->
        defmodule FilterPartial1Test do
          import Dx.Defd

          defd run() do
            Enum.filter(
              Enum.filter(List, &(__MODULE__.title(&1) == "Tasks")),
              &(&1.hourly_points == 0.2)
            )
          end

          def title(arg) do
            arg.title
          end
        end

        assert [] = load!(FilterPartial1Test.run())
      end)
    end)
  end

  test "filter partial condition 1 (private)", %{list: list} do
    assert_queries(["\"hourly_points\" = ANY('{0.2}')"], fn ->
      assert_stderr("not defined with defd", fn ->
        defmodule FilterPartial1PrivTest do
          import Dx.Defd

          defd run() do
            Enum.filter(
              Enum.filter(List, &(title(&1) == "Tasks")),
              &(&1.hourly_points == 0.2)
            )
          end

          defp title(arg) do
            arg.title
          end
        end

        assert [] = load!(FilterPartial1PrivTest.run())
      end)
    end)
  end

  test "filter partial condition 2", %{list: list} do
    assert_queries(["\"hourly_points\" = ANY('{1.0}')"], fn ->
      assert_stderr("pass/1 is not defined with defd", fn ->
        defmodule FilterPartial2Test do
          import Dx.Defd

          defd run() do
            Enum.filter(
              Enum.filter(List, &(__MODULE__.pass(&1.title) == "Tasks")),
              &(&1.hourly_points == 1.0)
            )
          end

          def pass(arg) do
            arg
          end
        end

        assert [^list] = load!(FilterPartial2Test.run())
      end)
    end)
  end

  test "filter partial condition 2 (private)", %{list: list} do
    assert_queries(["\"hourly_points\" = ANY('{1.0}')"], fn ->
      assert_stderr("pass/1 is not defined with defd", fn ->
        defmodule FilterPartial2PrivTest do
          import Dx.Defd

          defd run() do
            Enum.filter(
              Enum.filter(List, &(pass(&1.title) == "Tasks")),
              &(&1.hourly_points == 1.0)
            )
          end

          defp pass(arg) do
            arg
          end
        end

        assert [^list] = load!(FilterPartial2PrivTest.run())
      end)
    end)
  end

  test "filter partial condition 3 (indirect)", %{list: list} do
    assert_queries([["\"hourly_points\" = ANY('{1.0}')", "\"title\" = 'Tasks'"]], fn ->
      defmodule FilterPartial3IndirectTest do
        import Dx.Defd

        defd run() do
          Enum.filter(
            Enum.filter(List, &(title(&1) == "Tasks")),
            &(&1.hourly_points == 1.0)
          )
        end

        defd title(arg) do
          arg.title
        end
      end

      assert [^list] = load!(FilterPartial3IndirectTest.run())
    end)
  end

  test "filter partial condition 3 (indirect 2)", %{list: list} do
    assert_queries(["\"hourly_points\" = ANY('{1.0}')"], fn ->
      assert_stderr("pass/1 is not defined with defd", fn ->
        defmodule FilterPartial3Indirect2Test do
          import Dx.Defd

          defd run() do
            Enum.filter(
              Enum.filter(List, &(title(&1) == "Tasks")),
              &(&1.hourly_points == 1.0)
            )
          end

          defd title(arg) do
            pass(arg.title)
          end

          defp pass(arg) do
            arg
          end
        end

        assert [^list] = load!(FilterPartial3Indirect2Test.run())
      end)
    end)
  end

  test "filter partial condition 4 (indirect assoc)", %{list: list} do
    assert_queries([["\"hourly_points\" = ANY('{1.0}')", "\"email\" = 'bob@carz.com'"]], fn ->
      defmodule FilterPartial4IndirectTest do
        import Dx.Defd

        defd run() do
          Enum.filter(
            Enum.filter(List, &(user_email(&1) == "bob@carz.com")),
            &(&1.hourly_points == 1.0)
          )
        end

        defd user_email(list) do
          list.created_by.email
        end
      end

      assert [] = load!(FilterPartial4IndirectTest.run())
    end)
  end

  test "filter partial condition 5 (indirect assoc)", %{list: list} do
    assert_queries([["\"hourly_points\" = ANY('{1.0}')", "\"name\" = 'Admin'"]], fn ->
      defmodule FilterPartial5IndirectTest do
        import Dx.Defd

        defd run() do
          Enum.filter(
            Enum.filter(List, &(user_role(&1) == "Admin")),
            &(&1.hourly_points == 1.0)
          )
        end

        defd user_role(list) do
          list.created_by.role.name
        end
      end

      assert [] = load!(FilterPartial5IndirectTest.run())
    end)
  end

  test "filter based on static value from argument", %{list: list} do
    assert_queries(["\"hourly_points\" = ANY('{0.2}')"], fn ->
      refute_stderr(fn ->
        defmodule FilterStaticValTest do
          import Dx.Defd

          defd run(score) do
            Enum.filter(List, &(&1.hourly_points == score))
          end
        end

        load!(FilterStaticValTest.run(0.2))
      end)
    end)
  end

  test "filter based on map value from argument", %{list: list} do
    assert_queries(["\"hourly_points\" = ANY('{0.2}')"], fn ->
      refute_stderr(fn ->
        defmodule FilterMapValTest do
          import Dx.Defd

          defd run(context) do
            Enum.filter(List, &(&1.hourly_points == context.val))
          end
        end

        load!(FilterMapValTest.run(%{val: 0.2}))
      end)
    end)
  end

  test "filter based on nested map value from argument", %{list: list} do
    assert_queries(["\"hourly_points\" = ANY('{0.2}')"], fn ->
      refute_stderr(fn ->
        defmodule FilterNestedMapValTest do
          import Dx.Defd

          defd run(context) do
            Enum.filter(List, &(&1.hourly_points == context.nested.val))
          end
        end

        load!(FilterNestedMapValTest.run(%{nested: %{val: 0.2}}))
      end)
    end)
  end

  test "filter based on passed in schema field", %{user: user} do
    assert_queries(["\"title\" = ANY('{\"#{user.first_name}\"}')"], fn ->
      refute_stderr(fn ->
        defmodule FilterFieldArgTest do
          import Dx.Defd

          defd run(user) do
            Enum.filter(List, &(&1.title == user.first_name))
          end
        end

        load!(FilterFieldArgTest.run(user))
      end)
    end)
  end

  test "filter based on unloaded association field", %{user: user} do
    assert_queries(["FROM \"lists\"", "FROM \"roles\""], fn ->
      refute_stderr(fn ->
        defmodule FilterUnloadedFieldArgTest do
          import Dx.Defd

          defd run(user) do
            Enum.filter(List, &(&1.title == user.role.name))
          end
        end

        load!(FilterUnloadedFieldArgTest.run(user))
      end)
    end)
  end

  test "dynamically query schemas" do
    assert_queries(
      [
        "SELECT count(*) FROM \"tasks\"",
        "SELECT count(*) FROM \"lists\"",
        "SELECT count(*) FROM \"users\""
      ],
      fn ->
        refute_stderr(fn ->
          defmodule DynamicQueryTest do
            import Dx.Defd

            defd run() do
              Enum.map(
                [
                  non_dx(Dx.Scope.all(Task)),
                  non_dx(Dx.Scope.all(List)),
                  non_dx(Dx.Scope.all(User))
                ],
                &Enum.count(&1)
              )
            end
          end

          assert [1, 2, 1] = load!(DynamicQueryTest.run())
        end)
      end
    )
  end

  test "filter based on static condition", %{list: list} do
    refute_stderr(fn ->
      defmodule FilterStaticCondTest do
        import Dx.Defd

        defd run(field) do
          Enum.filter(List, fn list ->
            case field do
              :title -> list.title == "Tasks"
              :points -> list.hourly_points == 0.2
            end
          end)
        end
      end

      # assert_queries(["\"title\" = ANY('{\"Tasks\"}')"], fn ->
      assert_queries(["FROM \"lists\""], fn ->
        load!(FilterStaticCondTest.run(:title))
      end)

      # assert_queries(["\"hourly_points\" = ANY('{0.2}')"], fn ->
      assert_queries(["FROM \"lists\""], fn ->
        load!(FilterStaticCondTest.run(:points))
      end)
    end)
  end

  test "list all?" do
    assert_queries(["FROM \"lists\""], fn ->
      refute_stderr(fn ->
        defmodule All1Test do
          import Dx.Defd

          defd run() do
            Enum.all?(List)
          end
        end

        assert load!(All1Test.run()) == true
      end)
    end)
  end

  test "error all?" do
    refute_stderr(fn ->
      defmodule All1ErrorTest do
        import Dx.Defd

        @dx def: :original
        defd run() do
          Enum.all?(:error)
        end
      end

      assert_raise Dataloader.GetError, ~r/The given atom - :\w+ - is not a module./, fn ->
        load(All1ErrorTest.run())
      end

      # assert_same_error(
      #   Protocol.UndefinedError,
      #   location(-9 ),
      #   fn -> load!(All1ErrorTest.run()) end,
      #   fn -> All1ErrorTest.run() end
      # )
    end)
  end
end
