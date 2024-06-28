defmodule Dx.Defd.ExternalFnTest do
  use Dx.Test.DefdCase, async: false

  setup context do
    user_attrs = Enum.at(context[:users] || [], 0) || %{}
    user2_attrs = Enum.at(context[:users] || [], 1) || %{}

    user =
      create(
        User,
        {%{
           email: "zoria@max.net",
           verified_at: ~U[2022-01-13 00:01:00Z],
           role: %{name: "Assistant"}
         }, user_attrs}
      )

    user2 =
      create(
        User,
        {%{
           email: "charlie@xoom.ie",
           verified_at: ~U[2022-02-12 00:01:00Z],
           role: %{name: "Assistant"}
         }, user2_attrs}
      )

    assert user.verified_at > user2.verified_at
    assert DateTime.compare(user.verified_at, user2.verified_at) == :lt

    users = [user, user2]

    list = create(List, %{created_by: user, from_template: nil})

    tasks = [
      task = create(Task, %{list: list, created_by: user}),
      task2 = create(Task, %{list: list, created_by: user2}),
      create(Task, %{list: list, created_by: user}),
      create(Task, %{list: list, created_by: user2}),
      create(Task, %{list: list, created_by: user2})
    ]

    task_user_ids = Enum.map(tasks, & &1.created_by_id)
    task_user_emails = Enum.map(tasks, & &1.created_by.email)

    [
      user: unload(user),
      user2: unload(user2),
      users: unload(users),
      preloaded_user: user,
      preloaded_user2: user2,
      preloaded_users: users,
      preloaded_list: %{list | tasks: tasks},
      list: unload(list),
      preloaded_task: task,
      preloaded_task2: task2,
      task: unload(task),
      task2: unload(task2),
      tasks: Enum.map(tasks, &Repo.reload!/1),
      task_user_ids: task_user_ids,
      task_user_emails: task_user_emails,
      preloaded_tasks: tasks
    ]
  end

  test "loads associations referenced in external function",
       %{list: list, user: %{email: email}} do
    defmodule AnonFunAssoc do
      import Dx.Defd

      defd indirect_enum_map(list) do
        non_dx(
          defp_enum_map(list.tasks, fn _task ->
            list.created_by.email
          end)
        )
      end

      defp defp_enum_map(enum, fun), do: Enum.map(enum, fun)
    end

    assert load!(AnonFunAssoc.indirect_enum_map(list)) == [email, email, email, email, email]
  end

  test "loads duplicate reference once",
       %{list: list, user: user} do
    defmodule DoubleRefTest do
      import Dx.Defd

      defd double_mail(list) do
        non_dx(concat(list.created_by.email, list.created_by.email))
      end

      defp concat(a, b), do: a <> b
    end

    assert load(DoubleRefTest.double_mail(list)) == {:ok, user.email <> user.email}
  end

  test "loads duplicate defd reference once",
       %{list: list, user: user} do
    defmodule DoubleDefdRefTest do
      import Dx.Defd

      defd double_mail(list) do
        concatd(list.created_by.email, list.created_by.email)
      end

      defd(concatd(a, b), do: non_dx(concat(a, b)))
      defp concat(a, b), do: a <> b
    end

    assert load(DoubleDefdRefTest.double_mail(list)) == {:ok, user.email <> user.email}
  end

  test "loads deeply nested keys from external map" do
    defmodule DeeplyNestedMapTest do
      import Dx.Defd

      defp data(), do: %{a: %{b: %{c: :d}}}

      defd deeply_nested() do
        non_dx(data()).a.b.c
      end
    end

    assert load(DeeplyNestedMapTest.deeply_nested()) == {:ok, :d}
  end

  test "preserves anonymous function argument references",
       %{list: list, user: user} do
    defmodule AnonFunLocalTest do
      import Dx.Defd

      defd indirect_enum_map(list) do
        non_dx(
          defp_enum_map(list.tasks, fn task ->
            task.created_by_id == list.created_by.id
          end)
        )
      end

      defp defp_enum_map(enum, fun), do: Enum.map(enum, fun)
    end

    assert load!(AnonFunLocalTest.indirect_enum_map(list)) == [true, false, true, false, false]
  end

  test "Enum result as external function arg", %{list: list, preloaded_list: preloaded_list} do
    refute_stderr(fn ->
      defmodule NestedTest do
        import Dx.Defd

        @dx def: :original
        defd run(list) do
          Enum.map(list.tasks, fn task ->
            non_dx(
              simple_arg(
                Enum.find(task.created_by.lists, fn list ->
                  Enum.count(list.tasks) > 1
                end)
              )
            )
          end)
        end

        @dx def: :original
        defd run2(list) do
          Enum.map(list.tasks, fn task ->
            non_dx(
              __MODULE__.simple_arg(
                Enum.find(task.created_by.lists, fn list ->
                  Enum.count(list.tasks) > 1
                end)
              )
            )
          end)
        end

        def simple_arg(arg) do
          arg
        end
      end

      preloaded_list = Repo.preload(preloaded_list, tasks: [created_by: [lists: :tasks]])
      assert load!(NestedTest.run(list)) == unload(NestedTest.run(preloaded_list))
      assert load!(NestedTest.run2(list)) == unload(NestedTest.run2(preloaded_list))
    end)
  end

  test "Enum in external fn body", %{
    list: list,
    preloaded_list: preloaded_list,
    task: task,
    user: user
  } do
    refute_stderr(fn ->
      defmodule EnumInExtFnTest do
        import Dx.Defd

        @dx def: :original
        defd run(list) do
          non_dx(
            enum_map(list.tasks, fn task ->
              Enum.map([task], & &1.created_by.email)
            end)
          )
        end

        @dx def: :original
        defd run2(list) do
          non_dx(
            enum_map(list.tasks, fn task ->
              Enum.map([%{a: %{b: task}}], & &1.a.b.created_by.email)
            end)
          )
        end

        defp enum_map(enum, mapper) do
          Enum.map(enum, mapper)
        end
      end

      preloaded_list = Repo.preload(preloaded_list, tasks: :created_by)
      assert load!(EnumInExtFnTest.run(preloaded_list)) == EnumInExtFnTest.run(preloaded_list)
      assert load!(EnumInExtFnTest.run2(preloaded_list)) == EnumInExtFnTest.run2(preloaded_list)
    end)
  end

  test "nested Enum in external fn body", %{
    list: list,
    preloaded_list: preloaded_list,
    task: task,
    user: user
  } do
    refute_stderr(fn ->
      defmodule NestedEnumInExtFnTest do
        import Dx.Defd

        @dx def: :original
        defd run(list) do
          non_dx(
            enum_map(list.tasks, fn task ->
              Enum.map([task], & &1.created_by.email)
            end)
          )
        end

        @dx def: :original
        defd run2(list) do
          non_dx(
            enum_map(list.tasks, fn task ->
              enum_map([%{a: %{b: task}}], &(&1.a.b.created_by.email == task.created_by.email))
            end)
          )
        end

        defp enum_map(enum, mapper) do
          Enum.map(enum, mapper)
        end
      end

      preloaded_list = Repo.preload(preloaded_list, tasks: :created_by)

      assert load!(NestedEnumInExtFnTest.run(preloaded_list)) ==
               NestedEnumInExtFnTest.run(preloaded_list)

      assert load!(NestedEnumInExtFnTest.run2(preloaded_list)) ==
               NestedEnumInExtFnTest.run2(preloaded_list)
    end)
  end

  test "Invalid field in external fn body", %{
    list: list,
    preloaded_list: preloaded_list,
    task: task,
    user: user
  } do
    refute_stderr(fn ->
      defmodule InvalidFieldInExtFnTest do
        import Dx.Defd

        @dx def: :original
        defd run(list) do
          non_dx(
            enum_map(list.tasks, fn task ->
              Enum.map([task], & &1.unknown.email)
            end)
          )
        end

        @dx def: :original
        defd run2(list) do
          non_dx(
            enum_map(list.tasks, fn task ->
              Enum.map([%{a: %{b: task}}], & &1.a.b.unknown.email)
            end)
          )
        end

        defp enum_map(enum, mapper) do
          Enum.map(enum, mapper)
        end
      end

      assert_same_error(
        KeyError,
        location(-21),
        fn -> load!(InvalidFieldInExtFnTest.run(preloaded_list)) end,
        fn -> InvalidFieldInExtFnTest.run(preloaded_list) end
      )

      assert_same_error(
        KeyError,
        location(-19),
        fn -> load!(InvalidFieldInExtFnTest.run2(preloaded_list)) end,
        fn -> InvalidFieldInExtFnTest.run2(preloaded_list) end
      )
    end)
  end

  test "Invalid field in external fn body condition", %{
    list: list,
    preloaded_list: preloaded_list,
    task: task,
    user: user
  } do
    refute_stderr(fn ->
      defmodule InvalidFieldInExtFnCondTest do
        import Dx.Defd

        @dx def: :original
        defd run(list) do
          non_dx(
            enum_map(list.tasks, fn task ->
              Enum.map(
                [task],
                &if(Map.has_key?(&1, :unknown), do: &1.unknown.email, else: :unknown)
              )
            end)
          )
        end

        defp enum_map(enum, mapper) do
          Enum.map(enum, mapper)
        end
      end

      preloaded_list = Repo.preload(preloaded_list, tasks: :created_by)

      assert load!(InvalidFieldInExtFnCondTest.run(preloaded_list)) ==
               InvalidFieldInExtFnCondTest.run(preloaded_list)
    end)
  end

  test "Error accessing field on nil in external fn body", %{
    list: list,
    preloaded_list: preloaded_list
  } do
    refute_stderr(fn ->
      defmodule FieldOnNilInExtFnTest do
        import Dx.Defd

        @dx def: :original
        defd run(list) do
          non_dx(
            enum_map(list.tasks, fn task ->
              Enum.map([task], fn _ -> list.from_template.title end)
            end)
          )
        end

        defp enum_map(enum, mapper) do
          Enum.map(enum, mapper)
        end
      end

      assert_same_error(
        KeyError,
        location(-12),
        fn -> load!(FieldOnNilInExtFnTest.run(list)) end,
        fn -> FieldOnNilInExtFnTest.run(preloaded_list) end
      )
    end)
  end

  test "No error NOT accessing field on nil in external fn body", %{
    list: list,
    preloaded_list: preloaded_list
  } do
    refute_stderr(fn ->
      defmodule CondOnNilInExtFnTest do
        import Dx.Defd

        @dx def: :original
        defd run(list) do
          non_dx(
            enum_map(list.tasks, fn task ->
              Enum.map([task], fn _ -> false && list.from_template.title end)
            end)
          )
        end

        defp enum_map(enum, mapper) do
          Enum.map(enum, mapper)
        end
      end

      assert load!(CondOnNilInExtFnTest.run(list)) == CondOnNilInExtFnTest.run(preloaded_list)
    end)
  end

  test "function reference in fn body", %{
    list: list,
    preloaded_list: preloaded_list,
    task: task,
    user: user
  } do
    refute_stderr(fn ->
      defmodule FunRefInFnTest do
        import Dx.Defd

        @dx def: :original
        defd run(list) do
          non_dx(enum_map(list.tasks, &created_by_email/1))
        end

        @dx def: :original
        defd run2(list) do
          non_dx(enum_map(list.tasks, &__MODULE__.created_by_email/1))
        end

        def created_by_email(task) do
          task.created_by.email
        end

        defp enum_map(enum, mapper) do
          Enum.map(enum, mapper)
        end
      end

      preloaded_list = Repo.preload(preloaded_list, tasks: :created_by)

      assert load!(FunRefInFnTest.run(preloaded_list)) ==
               FunRefInFnTest.run(preloaded_list)

      assert load!(FunRefInFnTest.run2(preloaded_list)) ==
               FunRefInFnTest.run2(preloaded_list)
    end)
  end

  test "function reference in external fn body", %{
    list: list,
    preloaded_list: preloaded_list,
    task: task,
    user: user
  } do
    refute_stderr(fn ->
      defmodule FunRefInExtFnTest do
        import Dx.Defd

        @dx def: :original
        defd run(list) do
          non_dx(
            enum_map(list.tasks, fn task ->
              Enum.map([task], &created_by_email/1)
            end)
          )
        end

        @dx def: :original
        defd run2(list) do
          non_dx(
            enum_map(list.tasks, fn task ->
              Enum.map([task], &__MODULE__.created_by_email/1)
            end)
          )
        end

        def created_by_email(task) do
          task.created_by.email
        end

        defp enum_map(enum, mapper) do
          Enum.map(enum, mapper)
        end
      end

      preloaded_list = Repo.preload(preloaded_list, tasks: :created_by)

      assert load!(FunRefInExtFnTest.run(preloaded_list)) ==
               FunRefInExtFnTest.run(preloaded_list)

      assert load!(FunRefInExtFnTest.run2(preloaded_list)) ==
               FunRefInExtFnTest.run2(preloaded_list)
    end)
  end
end
