defmodule Infer.RefTest do
  use ExUnit.Case, async: true

  alias Infer.Test.Schema.Task

  import Test.Support.Factories

  defmodule TaskTemplate do
    defstruct [:title, :desc, :label]
  end

  defmodule Rules do
    use Infer.Rules, for: Task

    infer list_archived_at: {:ref, [:list, :archived_at]}

    infer applicable_label: :chore, when: %{args: %{context: %{label: nil}}}

    infer applicable_template: %TaskTemplate{
            label: {:ref, :applicable_label},
            title: "[Chore]",
            desc: "Steps to be done"
          },
          when: %{args: %{context: %{title: nil}}}
  end

  setup do
    task = build(Task, %{list: %{archived_at: ~U[2021-10-31 19:59:03Z]}})

    [task: task]
  end

  test "returns other field value as part of the assigns", %{task: task} do
    assert Infer.get!(task, :list_archived_at, extra_rules: Rules) == ~U[2021-10-31 19:59:03Z]
  end

  test "returns other predicate result as part of the assigns", %{task: task} do
    assert Infer.get!(task, :applicable_template,
             extra_rules: Rules,
             args: [context: %{label: nil, title: nil}]
           ) ==
             %TaskTemplate{label: :chore, title: "[Chore]", desc: "Steps to be done"}

    assert Infer.get!(task, :applicable_template,
             extra_rules: Rules,
             args: [context: %{label: :meeting, title: nil}]
           ) ==
             %TaskTemplate{label: nil, title: "[Chore]", desc: "Steps to be done"}
  end
end
