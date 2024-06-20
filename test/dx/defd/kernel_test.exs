defmodule Dx.Defd.KernelTest do
  use Dx.Test.DefdCase, async: false

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

  describe "+/2" do
    test "works", %{list: list, task: task} do
      defmodule PlusTest do
        import Dx.Defd

        defd add_one_hourly_point(list) do
          list.hourly_points + 1.0
        end
      end

      assert load!(PlusTest.add_one_hourly_point(list)) == 4.5
    end
  end

  describe "and/2" do
    test "works", %{list: list, task: task} do
      defmodule AndTest do
        import Dx.Defd

        defd run(list) do
          list.hourly_points > 1.0 and list.created_by.role.name == "Assistant"
        end
      end

      assert load!(AndTest.run(list)) == true
    end

    test "skips erroneous code", %{list: list, task: task} do
      defmodule AndSkipErrorTest do
        import Dx.Defd

        defd run(list) do
          list.hourly_points > 4.0 and list.unknown.code
        end
      end

      assert load!(AndSkipErrorTest.run(list)) == false
    end
  end

  describe "&&/2" do
    test "works with booleans", %{list: list, task: task} do
      defmodule AmpersandsTest do
        import Dx.Defd

        defd run(list) do
          list.hourly_points > 1.0 && list.created_by.role.name == "Assistant"
        end
      end

      assert load!(AmpersandsTest.run(list)) == true
    end

    test "works with truthy", %{list: list, task: task} do
      defmodule AmpersandsTest do
        import Dx.Defd

        defd run(list) do
          list && list.hourly_points && list.hourly_points > 1.0 && list.created_by.role.name
        end
      end

      assert_queries(["FROM \"users\"", "FROM \"roles\""], fn ->
        assert load!(AmpersandsTest.run(list)) == "Assistant"
      end)

      assert_queries([], fn ->
        assert load!(AmpersandsTest.run(%{list | hourly_points: nil})) == nil
        assert load!(AmpersandsTest.run(%{list | hourly_points: false})) == false
        assert load!(AmpersandsTest.run(%{list | hourly_points: 0.0})) == false
      end)
    end

    test "skips erroneous code", %{list: list, task: task} do
      defmodule AmpersandsSkipErrorTest do
        import Dx.Defd

        defd run(list) do
          list.hourly_points > 4.0 && list.unknown.code
        end
      end

      assert load!(AmpersandsSkipErrorTest.run(list)) == false
    end
  end

  describe "or/2" do
    test "works", %{list: list, task: task} do
      defmodule OrTest do
        import Dx.Defd

        defd run(list) do
          list.hourly_points > 4.0 or list.created_by.role.name == "Assistant"
        end
      end

      assert_queries(["FROM \"users\"", "FROM \"roles\""], fn ->
        assert load!(OrTest.run(list)) == true
      end)
    end

    test "skips erroneous code", %{list: list, task: task} do
      defmodule OrSkipErrorTest do
        import Dx.Defd

        defd run(list) do
          list.hourly_points > 1.0 or list.unknown.code
        end
      end

      assert load!(OrSkipErrorTest.run(list)) == true
    end
  end

  describe "if/2" do
    test "works with boolean condition", %{list: list, user: user} do
      defmodule IfBoolTest do
        import Dx.Defd

        defd run(list) do
          if list.hourly_points >= 2.0 do
            list.created_by.first_name
          end
        end

        defd run2(list) do
          if list.hourly_points >= 4.0 do
            list.created_by.first_name
          end
        end
      end

      assert_queries(["FROM \"users\""], fn ->
        assert load!(IfBoolTest.run(list)) == user.first_name
      end)

      assert_queries([], fn ->
        assert load!(IfBoolTest.run2(list)) == nil
      end)
    end

    test "works with truthy condition", %{list: list, user: user} do
      defmodule IfTruthyTest do
        import Dx.Defd

        defd run(list) do
          if list.hourly_points do
            list.created_by.first_name
          end
        end

        defd run2(list) do
          if !list.hourly_points do
            list.created_by.first_name
          end
        end
      end

      assert_queries(["FROM \"users\""], fn ->
        assert load!(IfTruthyTest.run(list)) == user.first_name
      end)

      assert_queries([], fn ->
        assert load!(IfTruthyTest.run2(list)) == nil
      end)
    end

    test "works with assignment",
         %{list: list, preloaded_user: preloaded_user} do
      defmodule IfAssignTest do
        import Dx.Defd

        defd run(list) do
          if creator = list.created_by do
            creator.role.name
          end
        end

        defd run2(list) do
          if creator = user = list.created_by do
            creator.role.name
          end
        end

        defd run3(list) do
          if creator = user = list.created_by do
            user.role.name
          end
        end
      end

      assert_queries(["FROM \"users\"", "FROM \"roles\""], fn ->
        assert load!(IfAssignTest.run(list)) == preloaded_user.role.name
      end)

      assert_queries(["FROM \"users\"", "FROM \"roles\""], fn ->
        assert load!(IfAssignTest.run2(list)) == preloaded_user.role.name
      end)

      assert_queries(["FROM \"users\"", "FROM \"roles\""], fn ->
        assert load!(IfAssignTest.run3(list)) == preloaded_user.role.name
      end)
    end

    test "skips erroneous code", %{list: list, user: user} do
      defmodule IfSkipErrorTest do
        import Dx.Defd

        defd run(list) do
          if list.hourly_points >= 4.0 do
            list.unknown.code
          end
        end
      end

      assert_queries([], fn ->
        assert load!(IfSkipErrorTest.run(list)) == nil
      end)
    end

    test "loads data before if", %{list: list, user: user} do
      defmodule IfLoadBeforeTest do
        import Dx.Defd

        defd run(list) do
          created_by = list.created_by
          first_name = created_by.first_name

          if list.hourly_points >= 2.0 do
            Enum.join([first_name, list.created_by.last_name], " ")
          end
        end
      end

      assert_queries(["FROM \"users\""], fn ->
        assert load!(IfLoadBeforeTest.run(list)) == "#{user.first_name} #{user.last_name}"
      end)
    end
  end
end
