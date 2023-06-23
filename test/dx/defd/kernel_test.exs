defmodule Dx.Defd.KernelTest do
  use Dx.Test.DefdCase, async: true

  setup do
    user = create(User, %{role: %{name: "Assistant"}})
    list = create(List, %{created_by: user, hourly_points: 3.5})
    task = create(Task, %{list: list, created_by: user})

    [
      user: Repo.reload!(user),
      preloaded_user: user,
      preloaded_list: %{list | tasks: [task]},
      list: Repo.reload!(list),
      preloaded_task: task,
      task: Repo.reload!(task)
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

      assert load(PlusTest.add_one_hourly_point(list)) == {:ok, 4.5}
    end
  end
end
