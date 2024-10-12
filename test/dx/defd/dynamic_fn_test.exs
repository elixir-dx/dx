defmodule Dx.Defd.DynamicFnTest do
  use Dx.Test.DefdCase, async: false

  setup context do
    user_attrs = context[:user] || %{}
    user = create(User, user_attrs)
    list = create(List, %{created_by: user})
    task = create(Task, %{list: list, created_by: user})

    [
      user: user,
      preloaded_list: list,
      list: unload(list),
      preloaded_task: task,
      task: unload(task)
    ]
  end

  test "calls dynamic function in variable", %{task: task, user: user} do
    defmodule DynFunTest do
      import Dx.Defd

      defd run(task) do
        fun = & &1.created_by.first_name
        load_task_count = fn -> Enum.count(Task) end
        "Created by: #{fun.(task)} (#{load_task_count.()} total)"
      end
    end

    assert load!(DynFunTest.run(task)) == "Created by: #{user.first_name} (1 total)"
  end

  test "calls multi-clause dynamic function in variable", %{task: task, list: list} do
    defmodule DynMultiClauseFunTest do
      import Dx.Defd

      defd run(tasks) do
        if_empty_then = fn
          [], next_filter -> Enum.filter(tasks, next_filter)
          result, _ -> result
        end

        []
        |> if_empty_then.(&(&1.created_by.first_name == "Joey"))
        |> if_empty_then.(&(&1.created_by.role && &1.created_by.role.name == "Admin"))
        |> if_empty_then.(fn _ -> true end)
      end
    end

    assert load!(DynMultiClauseFunTest.run([task])) == [task]

    joeys_task = create(Task, %{created_by: %{first_name: "Joey"}, list: list})
    assert load!(DynMultiClauseFunTest.run([task, joeys_task])) == [joeys_task]
  end

  test "calls dynamic function in passed in variable" do
    defmodule PassedInDynFunTest do
      import Dx.Defd

      defd nested_fun(map) do
        map.nested.fun.()
      end
    end

    assert PassedInDynFunTest.nested_fun(%{nested: %{fun: fn -> "Hi there!" end}})
           |> load() == {:ok, "Hi there!"}
  end

  test "calls function in passed in dynamic module" do
    defmodule PassedInDynModOther do
      def run() do
        "Hi there!"
      end
    end

    defmodule PassedInDynModTest do
      import Dx.Defd

      defd nested_fun(map) do
        map.nested.fun.run()
      end
    end

    assert PassedInDynModTest.nested_fun(%{nested: %{fun: PassedInDynModOther}})
           |> load() == {:ok, "Hi there!"}
  end

  test "loads associations on results of dynamic function call",
       %{task: task, user: %{email: user_email}} do
    defmodule DynFunResultTest do
      import Dx.Defd

      defd nested_fun(map) do
        map.nested.fun.().created_by.email
      end
    end

    assert DynFunResultTest.nested_fun(%{nested: %{fun: fn -> task end}})
           |> load() == {:ok, user_email}
  end
end
