defmodule Dx.Defd.BindTest do
  use Dx.Test.DefdCase, async: false

  describe "data loading" do
    setup do
      user = create(User, %{role: %{name: "Assistant"}})
      list = create(List, %{created_by: user})
      task = create(Task, %{list: list, created_by: user})

      [
        user: unload(user),
        preloaded_user: user,
        preloaded_list: %{list | tasks: [task]},
        list: unload(list),
        preloaded_task: task,
        task: unload(task)
      ]
    end

    test "binds field to variable & returns it", %{list: list} do
      refute_stderr(fn ->
        defmodule SimpleFieldTest do
          import Dx.Defd

          defd run(list) do
            title = list.title
            title
          end
        end

        assert load(SimpleFieldTest.run(list)) == {:ok, list.title}
      end)
    end

    test "binds field to dangling variable", %{list: list} do
      assert_stderr("is unused", fn ->
        defmodule StubFieldTest do
          import Dx.Defd

          defd run(list) do
            title = list.title
          end
        end

        assert load(StubFieldTest.run(list)) == {:ok, list.title}
      end)
    end

    test "pattern-matches field, binds to variable & returns it", %{list: list} do
      refute_stderr(fn ->
        defmodule SimpleFieldPatternTest do
          import Dx.Defd

          defd run(list) do
            %{title: title} = list
            title
          end
        end

        assert load(SimpleFieldPatternTest.run(list)) == {:ok, list.title}
      end)
    end

    test "binds assoc field to variable & returns it", %{list: list, user: user} do
      refute_stderr(fn ->
        defmodule AssocFieldTest do
          import Dx.Defd

          defd run(list) do
            email = list.created_by.email
            email
          end
        end

        assert load(AssocFieldTest.run(list)) == {:ok, user.email}
      end)
    end

    test "pattern-matches assoc field, binds to variable & returns it", %{list: list, user: user} do
      refute_stderr(fn ->
        defmodule AssocFieldPatternTest do
          import Dx.Defd

          defd run(list) do
            %{created_by: %{email: email}} = list
            email
          end
        end

        assert load(AssocFieldPatternTest.run(list)) == {:ok, user.email}
      end)
    end

    test "pattern-matches assoc field, binds to variable", %{list: list, user: user} do
      assert_stderr("is unused", fn ->
        defmodule AssocFieldPatternTest do
          import Dx.Defd

          defd run(list) do
            %{created_by: %{email: email}} = list
          end
        end

        assert load(AssocFieldPatternTest.run(list)) == {:ok, %{list | created_by: user}}
      end)
    end

    test "two dependent lines", %{list: list, user: user} do
      refute_stderr(fn ->
        defmodule SimpleMultiTest do
          import Dx.Defd

          defd run(list) do
            user = list.created_by
            user.email
          end
        end

        assert load(SimpleMultiTest.run(list)) == {:ok, user.email}
      end)
    end

    test "multiple dependent lines", %{list: list, preloaded_user: user} do
      refute_stderr(fn ->
        defmodule MultiTest do
          import Dx.Defd

          defd run(list) do
            user = list.created_by
            role = user.role
            role.name
          end
        end

        assert load(MultiTest.run(list)) == {:ok, user.role.name}
      end)
    end

    test "multiple dependent lines 2", %{list: list, preloaded_user: user} do
      refute_stderr(fn ->
        defmodule Multi2Test do
          import Dx.Defd

          defd run(list) do
            user = list.created_by
            role = user.role
            call(concat(user.email, role.name))
          end

          defp concat(a, b), do: a <> b
        end

        assert load(Multi2Test.run(list)) == {:ok, user.email <> user.role.name}
      end)
    end

    test "warns on non-binding line", %{list: list, preloaded_user: user} do
      assert_stderr("has no effect", fn ->
        defmodule IdleWarnTest do
          import Dx.Defd

          defd run(list) do
            user = list.created_by
            role = user.role
            user.email
            role.name
          end
        end

        assert load(IdleWarnTest.run(list)) == {:ok, user.role.name}
      end)
    end
  end
end
