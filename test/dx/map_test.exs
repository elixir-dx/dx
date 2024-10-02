defmodule Dx.MapTest do
  use Dx.Test.DataCase, async: true

  defmodule Rules do
    use Dx.Rules, for: Task

    infer prev_dates:
            {&Date.range/3,
             [
               {&Date.add/2, [{:ref, :due_on}, -1]},
               {&Date.add/2, [{:ref, :due_on}, -7]},
               -1
             ]}

    infer prev_tasks_1:
            {:map, :prev_dates, :due_on,
             {:query_one, Task, due_on: {:bound, :due_on}, created_by_id: {:ref, :created_by_id}}}

    infer prev_tasks_2:
            {:map, :prev_dates, {:bind, :due_on},
             {:query_one, Task, due_on: {:bound, :due_on}, created_by_id: {:ref, :created_by_id}}}

    infer prev_tasks_3:
            {:map, :prev_dates, {:bind, :due_on, %{}},
             {:query_one, Task, due_on: {:bound, :due_on}, created_by_id: {:ref, :created_by_id}}}
  end

  setup do
    user = create(User)
    list = create(List, %{created_by_id: user.id})

    tasks =
      for date <- Date.range(today(), today(-6), -1) do
        create(Task, %{due_on: date, list_id: list.id, created_by_id: user.id})
      end

    [tasks: tasks]
  end

  test "returns correct result (syntax 1)", %{tasks: [task | tasks]} do
    assert Dx.load!(task, :prev_tasks_1, extra_rules: Rules) ==
             tasks ++ [nil]
  end

  test "returns correct result (syntax 2)", %{tasks: [task | tasks]} do
    assert Dx.load!(task, :prev_tasks_2, extra_rules: Rules) ==
             tasks ++ [nil]
  end

  test "returns correct result (syntax 3)", %{tasks: [task | tasks]} do
    assert Dx.load!(task, :prev_tasks_3, extra_rules: Rules) ==
             tasks ++ [nil]
  end
end
