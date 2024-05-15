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

  test "list template efficiency", %{list_template: list_template} do
    assert_queries(["\"title\" = ANY('{\"Tasks\"}')"], fn ->
      refute_stderr(fn ->
        defmodule ScopeTest1 do
          import Dx.Defd

          defd run() do
            Enum.filter(List, &(&1.title == "Tasks"))
          end
        end

        assert [%List{title: "Tasks"}] = load!(ScopeTest1.run())
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
    assert_queries([["\"hourly_points\" = ANY('{1.0}')", "\"title\" = 'Tasks'"]], fn ->
      refute_stderr(fn ->
        defmodule FilterDefdRefTest do
          import Dx.Defd

          defd run() do
            Enum.filter(
              Enum.filter(List, &title/1),
              &(&1.hourly_points == 1.0)
            )
          end

          defd title(list) do
            list.title == "Tasks"
          end
        end

        assert [^list] = load!(FilterDefdRefTest.run())
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
