defmodule Infer.QueryOneTest do
  # async: false to receive :ecto_query messages correctly
  use Infer.Test.DataCase, async: false

  import Test.Support.DateTimeHelpers, only: [monday: 1]

  defmodule Rules do
    use Infer.Rules, for: Task

    infer calendar_override:
            {:query_one, ListCalendarOverride, date: {:ref, :due_on}, list_id: {:ref, :list_id}}

    infer first_calendar_override:
            {:query_first, ListCalendarOverride, date: {:ref, :due_on}, list_id: {:ref, :list_id}}

    infer calendar_overrides:
            {:query_all, ListCalendarOverride, date: {:ref, :due_on}, list_id: {:ref, :list_id}}
  end

  setup do
    main_list = create(List, %{created_by: %{}})
    other_list = create(List, %{created_by: %{}})
    lists = [main_list, other_list]

    calendar_overrides =
      for date_offset <- 0..3, list <- Enum.reverse(lists) do
        create(ListCalendarOverride, %{date: monday(date_offset), list_id: list.id})
      end

    tasks =
      for date_offset <- 0..3 do
        create(Task, %{due_on: monday(date_offset), list_id: main_list.id, created_by: %{}})
      end

    [
      tasks: tasks,
      lists: lists,
      calendar_overrides: calendar_overrides
    ]
  end

  # subscribe to ecto queries
  setup do
    test_process = self()
    handler_id = "ecto-queries-test"

    callback = fn
      _event, _measurements, %{result: {:ok, %{command: :select}}} = metadata, _config ->
        send(test_process, {:ecto_query, metadata})

      _, _, _, _ ->
        nil
    end

    :ok = :telemetry.attach(handler_id, [:infer, :test, :repo, :query], callback, nil)

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)
  end

  describe "query_one" do
    test "returns single calendar_override", %{
      tasks: [task | _],
      calendar_overrides: calendar_overrides
    } do
      expected =
        calendar_overrides
        |> Enum.find(&(&1.date == task.due_on and &1.list_id == task.list_id))

      assert Infer.load!(task, :calendar_override, extra_rules: Rules) ==
               expected

      assert_received {:ecto_query,
                       %{source: "list_calendar_overrides", result: {:ok, %{num_rows: 1}}}}

      refute_received {:ecto_query, %{source: "list_calendar_overrides"}}
    end

    test "returns multiple calendar_overrides in one ecto query", %{
      tasks: tasks,
      calendar_overrides: calendar_overrides
    } do
      expected =
        for {task, task} <- Enum.zip(tasks, tasks) do
          calendar_overrides
          |> Enum.find(&(&1.date == task.due_on and &1.list_id == task.list_id))
        end

      assert Infer.load!(tasks, :calendar_override, extra_rules: Rules) ==
               expected

      assert_received {:ecto_query,
                       %{source: "list_calendar_overrides", result: {:ok, %{num_rows: 4}}}}

      refute_received {:ecto_query, %{source: "list_calendar_overrides"}}
    end
  end

  describe "query_first" do
    test "returns single calendar_override", %{
      tasks: [task | _],
      calendar_overrides: calendar_overrides
    } do
      expected =
        calendar_overrides
        |> Enum.find(&(&1.date == task.due_on and &1.list_id == task.list_id))

      assert Infer.load!(task, :first_calendar_override, extra_rules: Rules) ==
               expected

      assert_received {:ecto_query, %{source: nil, result: {:ok, %{num_rows: 1}}}}
      refute_received {:ecto_query, %{source: nil}}
      refute_received {:ecto_query, %{source: "list_calendar_overrides"}}
    end

    test "returns multiple calendar_overrides in one ecto query", %{
      tasks: tasks,
      calendar_overrides: calendar_overrides
    } do
      expected =
        for {task, task} <- Enum.zip(tasks, tasks) do
          calendar_overrides
          |> Enum.find(&(&1.date == task.due_on and &1.list_id == task.list_id))
        end

      assert Infer.load!(tasks, :first_calendar_override, extra_rules: Rules) ==
               expected

      assert_received {:ecto_query, %{source: nil, result: {:ok, %{num_rows: 4}}}}
      refute_received {:ecto_query, %{source: nil}}
      refute_received {:ecto_query, %{source: "list_calendar_overrides"}}
    end
  end

  describe "query_all" do
    test "returns single calendar_override", %{
      tasks: [task | _],
      calendar_overrides: calendar_overrides
    } do
      expected =
        calendar_overrides
        |> Enum.filter(&(&1.date == task.due_on and &1.list_id == task.list_id))

      assert Infer.load!(task, :calendar_overrides, extra_rules: Rules) ==
               expected

      assert_received {:ecto_query,
                       %{source: "list_calendar_overrides", result: {:ok, %{num_rows: 1}}}}

      refute_received {:ecto_query, %{source: "list_calendar_overrides"}}
    end

    test "returns multiple calendar_overrides in one ecto query", %{
      tasks: tasks,
      calendar_overrides: calendar_overrides
    } do
      expected =
        for {task, task} <- Enum.zip(tasks, tasks) do
          calendar_overrides
          |> Enum.filter(&(&1.date == task.due_on and &1.list_id == task.list_id))
        end

      assert Infer.load!(tasks, :calendar_overrides, extra_rules: Rules) ==
               expected

      assert_received {:ecto_query,
                       %{source: "list_calendar_overrides", result: {:ok, %{num_rows: 4}}}}

      refute_received {:ecto_query, %{source: "list_calendar_overrides"}}
    end
  end
end
