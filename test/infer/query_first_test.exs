defmodule Infer.QueryFirstTest do
  use Infer.Test.DataLoadingCase

  defmodule Rules do
    use Infer.Rules, for: List

    infer newest_completed_task:
            {:query_first, Task, [list_id: {:ref, :id}], order_by: [desc: :completed_at]}

    infer completed_tasks:
            {:query_all, Task, [list_id: {:ref, :id}],
             order_by: [asc: :title, desc: :completed_at]}
  end

  setup do
    user = create(User)
    lists = for _ <- 1..2, do: create(List, %{created_by_id: user.id})

    tasks =
      lists
      |> Enum.flat_map(fn list ->
        for date_offset <- 1..5 do
          create(Task, %{
            title: "Task #{date_offset}",
            created_by_id: user.id,
            list_id: list.id,
            completed_at: today(-date_offset, ~T[12:34:56])
          })
        end
      end)

    [lists: lists, tasks: tasks]
  end

  describe "query_first" do
    test "returns tasks for one list", %{lists: [list | _], tasks: tasks} do
      expected =
        tasks
        |> Enum.filter(&(&1.list_id == list.id))
        |> Enum.max_by(& &1.completed_at, DateTime)

      assert Infer.load!(list, :newest_completed_task, extra_rules: Rules) ==
               expected

      assert_received {:ecto_query, %{source: nil, result: {:ok, %{num_rows: 1}}}}
      refute_received {:ecto_query, %{source: nil}}
      refute_received {:ecto_query, %{source: "tasks"}}
    end

    test "returns events for multiple lists", %{lists: lists, tasks: tasks} do
      expected =
        for list <- lists do
          tasks
          |> Enum.filter(&(&1.list_id == list.id))
          |> Enum.max_by(& &1.completed_at, DateTime)
        end

      assert Infer.load!(lists, :newest_completed_task, extra_rules: Rules) ==
               expected

      assert_received {:ecto_query, %{source: nil, result: {:ok, %{num_rows: 2}}}}
      refute_received {:ecto_query, %{source: nil}}
      refute_received {:ecto_query, %{source: "tasks"}}
    end
  end

  describe "query_all" do
    test "returns events for one list", %{lists: [list | _], tasks: tasks} do
      expected =
        tasks
        |> Enum.filter(&(&1.list_id == list.id))
        |> Enum.sort_by(& &1.completed_at, {:desc, DateTime})
        |> Enum.sort_by(& &1.title)

      assert Infer.load!(list, :completed_tasks, extra_rules: Rules) ==
               expected

      assert_received {:ecto_query, %{source: "tasks", result: {:ok, %{num_rows: 5}}}}
      refute_received {:ecto_query, %{source: "tasks"}}
    end

    test "returns events for multiple lists", %{lists: lists, tasks: tasks} do
      expected =
        for list <- lists do
          tasks
          |> Enum.filter(&(&1.list_id == list.id))
          |> Enum.sort_by(& &1.completed_at, {:desc, DateTime})
          |> Enum.sort_by(& &1.title)
        end

      assert Infer.load!(lists, :completed_tasks, extra_rules: Rules) ==
               expected

      assert_received {:ecto_query, %{source: "tasks", result: {:ok, %{num_rows: 10}}}}
      refute_received {:ecto_query, %{source: "tasks"}}
    end
  end
end
