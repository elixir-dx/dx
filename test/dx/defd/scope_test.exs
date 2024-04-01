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
      list: unload(list),
      list2: unload(list2),
      list_template: unload(list_template),
      preloaded_task: task,
      task: unload(task)
    ]
  end

  # test "list all", %{list_template: list_template} do
  #   refute_stderr(fn ->
  #     defmodule ScopeAllTest do
  #       import Dx.Defd

  #       defd run() do
  #         List
  #       end
  #     end

  #     assert {:ok, [%List{title: "Tasks"}]} = load(ScopeAllTest.run())
  #   end)
  # end

  # test "list template efficiencyx" do
  #   import Ecto.Query

  #   select = %{
  #     0 => dynamic([l], l),
  #     1 => dynamic([l], l.id > 1)
  #   }

  #   from(l in List, select: ^select)
  #   |> Repo.all()
  #   |> dbg()
  # end

  test "list template efficiency", %{list_template: list_template} do
    refute_stderr(fn ->
      defmodule ScopeTest1 do
        import Dx.Defd

        defd run() do
          Enum.filter(List, &(&1.title == "Tasks"))
        end
      end

      assert [%List{title: "Tasks"}] = load!(ScopeTest1.run())
    end)
  end

  test "filter twice", %{list: %{id: list_id}} do
    refute_stderr(fn ->
      defmodule ScopeTest2 do
        import Dx.Defd

        defd run() do
          Enum.filter(Enum.filter(List, &(&1.title == "Tasks")), &(&1.hourly_points == 1.0))
        end
      end

      assert [%List{title: "Tasks"}] = load!(ScopeTest2.run())
    end)
  end

  test "list map", %{user: user} do
    refute_stderr(fn ->
      defmodule MapTest do
        import Dx.Defd

        defd run() do
          Enum.map(List, & &1.created_by)
        end
      end

      assert [^user, ^user] = load!(MapTest.run())
    end)
  end

  test "list filter map", %{user: user} do
    refute_stderr(fn ->
      defmodule FilterMapTest do
        import Dx.Defd

        defd run() do
          Enum.map(Enum.filter(List, &(&1.title == "Tasks")), & &1.created_by)
        end
      end

      assert [^user] = load!(FilterMapTest.run())
    end)
  end

  test "filter empty lists", %{list: list} do
    refute_stderr(fn ->
      defmodule FilterEmptyTest do
        import Dx.Defd

        defd run() do
          Enum.filter(List, &(Enum.count(&1.tasks) == 1))
        end
      end

      assert [^list] = load!(FilterEmptyTest.run())
    end)
  end

  test "filter using defd condition", %{list: list} do
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
  end

  test "filter using combined defd condition", %{list: list} do
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

        defd title(list) do
          list.title == "Tasks"
        end
      end

      assert [^list] = load!(FilterDefdRefTest.run())
    end)
  end

  test "filter using pseudo-remote defd function", %{list: list} do
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
  end

  test "filter partial condition 1", %{list: list} do
    refute_stderr(fn ->
      defmodule FilterPartial1Test do
        import Dx.Defd

        defd run() do
          Enum.filter(
            Enum.filter(List, &(__MODULE__.title(&1) == "Tasks")),
            &(&1.hourly_points == 1.0)
          )
        end

        defp title(arg) do
          arg.title
        end
      end

      assert [^list] = load!(FilterPartial1Test.run())
    end)
  end

  # test "filter partial condition 2", %{list: list} do
  #   refute_stderr(fn ->
  #     defmodule FilterPartial2Test do
  #       import Dx.Defd

  #       defd run() do
  #         Enum.filter(
  #           Enum.filter(List, &(__MODULE__.pass(&1.title) == "Tasks")),
  #           &(&1.hourly_points == 1.0)
  #         )
  #       end

  #       defp pass(arg) do
  #         arg
  #       end
  #     end

  #     assert [^list] = load!(FilterPartial2Test.run())
  #   end)
  # end

  # test "list all?" do
  #   refute_stderr(fn ->
  #     defmodule All1Test do
  #       import Dx.Defd

  #       defd run() do
  #         Enum.all?(List)
  #       end
  #     end

  #     assert load!(All1Test.run()) == true
  #   end)
  # end

  # test "error all?" do
  #   refute_stderr(fn ->
  #     defmodule All1ErrorTest do
  #       import Dx.Defd

  #       @dx def: :original
  #       defd run() do
  #         Enum.all?(:error)
  #       end
  #     end

  #     assert_raise Dataloader.GetError, ~r/The given atom - :\w+ - is not a module./, fn ->
  #       load(All1ErrorTest.run())
  #     end

  #     # assert_same_error(
  #     #   Protocol.UndefinedError,
  #     #   location(-9 ),
  #     #   fn -> load!(All1ErrorTest.run()) end,
  #     #   fn -> All1ErrorTest.run() end
  #     # )
  #   end)
  # end
end
