defmodule Dx.Defd.CondTest do
  use Dx.Test.DefdCase, async: false

  describe "with data" do
    setup do
      user = create(User, %{role: %{name: "Assistant"}})
      list = create(List, %{created_by: user, hourly_points: 3.5})
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

    test "works with boolean condition", %{list: list, user: user} do
      defmodule CondBoolTest do
        import Dx.Defd

        defd run(list) do
          cond do
            list.hourly_points >= 4.0 ->
              list.created_by.last_name

            list.hourly_points >= 2.0 ->
              list.created_by.first_name

            true ->
              nil
          end
        end
      end

      assert_queries(["FROM \"users\""], fn ->
        assert load!(CondBoolTest.run(list)) == user.first_name
      end)

      assert_queries(["FROM \"users\""], fn ->
        assert load!(CondBoolTest.run(%{list | hourly_points: 5.0})) == user.last_name
      end)

      assert_queries([], fn ->
        assert load!(CondBoolTest.run(%{list | hourly_points: 1.0})) == nil
      end)
    end

    test "works with truthy condition", %{list: list, user: user} do
      defmodule CondTruthyTest do
        import Dx.Defd

        defd run(list) do
          cond do
            list.hourly_points ->
              list.created_by.first_name

            true ->
              nil
          end
        end
      end

      assert_queries(["FROM \"users\""], fn ->
        assert load!(CondTruthyTest.run(list)) == user.first_name
      end)

      assert_queries([], fn ->
        assert load!(CondTruthyTest.run(%{list | hourly_points: nil})) == nil
      end)
    end

    test "works with assignment",
         %{list: list, preloaded_user: preloaded_user} do
      defmodule CondAssignTest do
        import Dx.Defd

        defd run(list) do
          cond do
            points = list.hourly_points ->
              points

            creator = _user = list.created_by ->
              creator.role.name

            _creator = user = list.created_by ->
              user.role.name

            true ->
              nil
          end
        end
      end

      assert_queries([], fn ->
        assert load!(CondAssignTest.run(list)) == list.hourly_points
      end)

      assert_queries(["FROM \"users\"", "FROM \"roles\""], fn ->
        assert load!(CondAssignTest.run(%{list | hourly_points: nil})) == preloaded_user.role.name
      end)

      assert_queries([], fn ->
        assert load!(CondAssignTest.run(%{list | hourly_points: nil, created_by: nil})) == nil
      end)
    end

    test "skips erroneous code", %{list: list, user: user} do
      defmodule CondSkipErrorTest do
        import Dx.Defd

        defd run(list) do
          cond do
            list.hourly_points >= 4.0 ->
              list.unknown.code

            true ->
              nil
          end
        end
      end

      assert_queries([], fn ->
        assert load!(CondSkipErrorTest.run(list)) == nil
      end)
    end

    test "loads data before cond", %{list: list, user: user} do
      defmodule CondLoadBeforeTest do
        import Dx.Defd

        defd run(list) do
          created_by = list.created_by
          first_name = created_by.first_name

          cond do
            list.hourly_points >= 2.0 ->
              Enum.join([first_name, list.created_by.last_name], " ")

            true ->
              nil
          end
        end
      end

      assert_queries(["FROM \"users\""], fn ->
        assert load!(CondLoadBeforeTest.run(list)) == "#{user.first_name} #{user.last_name}"
      end)
    end

    test "loads data assigned before cond", %{list: list, user: user} do
      defmodule CondLoadAssignedBeforeTest do
        import Dx.Defd

        defd run(list) do
          _created_by = list.created_by
          l = Enum.find(List, &(&1.id == list.id))

          cond do
            l.hourly_points >= 2.0 ->
              l.hourly_points

            true ->
              nil
          end
        end
      end

      assert_queries(["FROM \"users\"", "FROM \"lists\""], fn ->
        assert load!(CondLoadAssignedBeforeTest.run(list)) == list.hourly_points
      end)
    end

    test "raises when no condition matches", %{list: list, user: user} do
      defmodule CondRaiseTest do
        import Dx.Defd

        @dx def: :original
        defd run(list) do
          cond do
            list.hourly_points >= 4.0 ->
              list.created_by.last_name
          end
        end
      end

      assert_same_error(
        CondClauseError,
        location(-8),
        fn -> load!(CondRaiseTest.run(list)) end,
        fn -> CondRaiseTest.run(list) end
      )
    end
  end

  test "works with complex conditions" do
    defmodule CondTest do
      import Dx.Defd

      defd run(list, author, acc) do
        cond do
          list.title == "Main list" and list.published? == false ->
            non_dx(Map.replace!(acc, :counter, 0))

          list.published? == false ->
            inc_counter(acc, list)

          is_nil(author) ->
            inc_counter(acc, list)

          not admin?(author) ->
            inc_counter(acc, list)

          admin?(author) and is_nil(author.verified_at) ->
            non_dx(Map.replace!(acc, :counter, 0))

          admin?(author) ->
            acc
        end
      end

      defd admin?(nil) do
        false
      end

      defd admin?(user) do
        user.role.name == "Admin"
      end

      defd inc_counter(acc, list) do
        non_dx(Map.update(acc, list.title, 1, &(&1 + 1)))
      end
    end

    admin = create(User, %{role: %{name: "Admin"}, verified_at: nil})

    verified_admin =
      create(User, %{
        role: %{name: "Admin"},
        verified_at: DateTime.truncate(DateTime.utc_now(), :second)
      })

    assistant = create(User, %{role: %{name: "Assistant"}})

    assert create(List, %{
             title: "Main list",
             published?: false,
             created_by: assistant
           })
           |> CondTest.run(nil, %{counter: 1, foo: :bar})
           |> load!() == %{counter: 0, foo: :bar}

    assert create(List, %{
             title: "Drafts",
             published?: false,
             created_by: assistant
           })
           |> CondTest.run(nil, %{counter: 1, foo: :bar})
           |> load!() ==
             %{:counter => 1, :foo => :bar, "Drafts" => 1}

    assert create(List, %{
             title: "Main list",
             published?: true,
             created_by: assistant
           })
           |> CondTest.run(nil, %{counter: 1, foo: :bar})
           |> load!() == %{:counter => 1, :foo => :bar, "Main list" => 1}

    assert create(List, %{
             title: "Main list",
             published?: true,
             created_by: assistant
           })
           |> CondTest.run(assistant, %{counter: 1, foo: :bar})
           |> load!() == %{:counter => 1, :foo => :bar, "Main list" => 1}

    assert create(List, %{
             title: "Main list",
             published?: true,
             created_by: assistant
           })
           |> CondTest.run(admin, %{counter: 1, foo: :bar})
           |> load!() == %{:counter => 0, :foo => :bar}

    assert create(List, %{
             title: "Main list",
             published?: true,
             created_by: assistant
           })
           |> CondTest.run(verified_admin, %{counter: 1, foo: :bar})
           |> load!() == %{:counter => 1, :foo => :bar}
  end
end
