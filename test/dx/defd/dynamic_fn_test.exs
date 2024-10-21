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

  test "non-loading multi-clause function", %{task: task, list: list} do
    defmodule SimpleMultiClauseFunTest do
      import Dx.Defd

      defd run(tasks) do
        name = "Joey"

        joeys_fun = fn
          task when is_binary(name) -> task.created_by.first_name == name
        end

        Enum.filter(tasks, joeys_fun)
      end
    end

    assert load!(SimpleMultiClauseFunTest.run([task])) == []

    joeys_task = create(Task, %{created_by: %{first_name: "Joey"}, list: list})
    assert load!(SimpleMultiClauseFunTest.run([task, joeys_task])) == [joeys_task]
  end

  test "non-loading multi-clause function 2", %{task: task, list: list} do
    defmodule SimpleMultiClauseFunTest2 do
      import Dx.Defd

      defd run(task) do
        name = "Joey"

        fun = fn
          task, _id when is_binary(name) when not is_nil(name) when not is_integer(name) ->
            {task, name}
        end

        fun.(task, 1)
      end
    end

    assert load!(SimpleMultiClauseFunTest2.run(task)) == {task, "Joey"}
  end

  test "scope fallback for multi-clause dynamic function in variable", %{task: task, list: list} do
    defmodule ScopeMultiClauseFunTest do
      import Dx.Defd

      defd run(tasks) do
        joeys_fun = fn
          %{created_by: %{first_name: "Joey"}} -> true
          _other -> false
        end

        Enum.filter(tasks, joeys_fun)
      end
    end

    assert load!(ScopeMultiClauseFunTest.run([task])) == []

    joeys_task = create(Task, %{created_by: %{first_name: "Joey"}, list: list})
    assert load!(ScopeMultiClauseFunTest.run([task, joeys_task])) == [joeys_task]
  end

  test "multi-clause function with guards", %{task: task, list: list} do
    defmodule GuardedMultiClauseFunTest do
      import Dx.Defd

      defd run(tasks) do
        joeys_fun = fn
          %{created_by: %{first_name: name}} when is_binary(name) -> false
          _other -> true
        end

        Enum.filter(tasks, joeys_fun)
      end
    end

    assert load!(GuardedMultiClauseFunTest.run([task])) == []

    joeys_task = create(Task, %{created_by: %{first_name: "Joey"}, list: list})
    assert load!(GuardedMultiClauseFunTest.run([task, joeys_task])) == []
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
