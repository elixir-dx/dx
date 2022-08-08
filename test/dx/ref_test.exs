defmodule Dx.RefTest do
  use ExUnit.Case, async: true

  alias Dx.Test.Schema.Task

  import Test.Support.Factories

  defmodule TaskTemplate do
    defstruct [:title, :desc, :label]
  end

  defmodule Rules do
    use Dx.Rules, for: Task

    infer list_archived_at: {:ref, [:list, :archived_at]}

    infer applicable_label: :chore, when: %{args: %{context: %{label: nil}}}

    infer applicable_template: %TaskTemplate{
            label: {:ref, :applicable_label},
            title: "[Chore]",
            desc: "Steps to be done"
          },
          when: %{args: %{context: %{title: nil}}}
  end

  describe "expanded" do
    @tag :skip
    test "expands predicate" do
      eval = Dx.Evaluation.from_options(extra_rules: Rules)
      {expanded, type} = Dx.Schema.expand_mapping(:list_archived_at, Task, eval)
      assert expanded == nil
      assert type == nil
    end
  end

  setup do
    task = build(Task, %{list: %{archived_at: ~U[2021-10-31 19:59:03Z]}})

    [task: task]
  end

  test "returns other field value as part of the assigns", %{task: task} do
    assert Dx.get!(task, :list_archived_at, extra_rules: Rules) == ~U[2021-10-31 19:59:03Z]
  end

  @tag :skip
  test "returns other predicate result as part of the assigns", %{task: task} do
    assert Dx.get!(task, :applicable_template,
             extra_rules: Rules,
             args: [context: %{label: nil, title: nil}]
           ) ==
             %TaskTemplate{label: :chore, title: "[Chore]", desc: "Steps to be done"}

    assert Dx.get!(task, :applicable_template,
             extra_rules: Rules,
             args: [context: %{label: :meeting, title: nil}]
           ) ==
             %TaskTemplate{label: nil, title: "[Chore]", desc: "Steps to be done"}
  end
end
