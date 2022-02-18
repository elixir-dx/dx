defmodule Infer.MapTest do
  use Infer.Test.DataCase, async: true

  import Test.Support.Factories
  import Test.Support.DateTimeHelpers, only: [monday: 0, monday: 1]

  defmodule Rules do
    use Infer.Rules, for: Task

    infer prev_dates:
            {&Date.range/2,
             [
               {&Date.add/2, [{:ref, :due_on}, -1]},
               {&Date.add/2, [{:ref, :due_on}, -7]}
             ]}

    infer prev_tasks_1:
            {:map, :prev_dates, :due_on,
             {:query_one, Task,
              due_on: {:bound, :due_on}, created_by_id: {:ref, :created_by_id}}}

    infer prev_tasks_2:
            {:map, :prev_dates, {:bind, :due_on},
             {:query_one, Task,
              due_on: {:bound, :due_on}, created_by_id: {:ref, :created_by_id}}}

    infer prev_tasks_3:
            {:map, :prev_dates, {:bind, :due_on, %{}},
             {:query_one, Task,
              due_on: {:bound, :due_on}, created_by_id: {:ref, :created_by_id}}}
  end

  setup do
    user = build(User) |> Repo.insert!
    list = build(List, %{created_by_id: user.id}) |> Repo.insert!
    tasks =
      for date <- Date.range(monday(), monday(-6)) do
        build(Task, %{due_on: date, list_id: list.id, created_by_id: user.id})
        |> Repo.insert!()
      end

    [tasks: tasks]
  end

  test "returns correct result (syntax 1)", %{tasks: [task | tasks]} do
    assert Infer.load!(task, :prev_tasks_1, extra_rules: Rules) ==
             tasks ++ [nil]
  end

  test "returns correct result (syntax 2)", %{tasks: [task | tasks]} do
    assert Infer.load!(task, :prev_tasks_2, extra_rules: Rules) ==
             tasks ++ [nil]
  end

  test "returns correct result (syntax 3)", %{tasks: [task | tasks]} do
    assert Infer.load!(task, :prev_tasks_3, extra_rules: Rules) ==
             tasks ++ [nil]
  end
end
