defmodule Infer.FunctionTest do
  use Infer.Test.DataCase, async: true

  defmodule Rules do
    use Infer.Rules, for: Task

    infer plus_2: {&Kernel.+/2, [{:ref, [:args, :number]}, 2]}

    infer list_hourly_points: {:ref, [:list, :hourly_points]},
          when: %{list: %{hourly_points: {:not, nil}}}

    infer list_hourly_points: 0.2

    infer task_points:
            {&Kernel.round/1,
             {&Kernel.*/2,
              [
                {:ref, :list_hourly_points},
                {&Timex.diff/3, [{:ref, :completed_at}, {:ref, :inserted_at}, :hours]}
              ]}}
  end

  setup context do
    overrides = context[:task] || %{}

    task =
      build(
        Task,
        {%{
           list: %{},
           inserted_at: today(~T[07:00:00]),
           completed_at: today(~T[20:00:00])
         }, overrides}
      )

    [task: task]
  end

  test "adds two numbers", %{task: task} do
    assert Infer.get!(task, :plus_2, extra_rules: Rules, args: [number: 2]) == 4
  end

  @tag task: %{list: %{hourly_points: nil}}
  test "returns fallback rate", %{task: task} do
    assert Infer.load!(task, :task_points, extra_rules: Rules) == 3
  end

  @tag task: %{list: %{hourly_points: 0.5}}
  test "returns referenced rate", %{task: task} do
    assert Infer.load!(task, :task_points, extra_rules: Rules) == 7
  end
end
