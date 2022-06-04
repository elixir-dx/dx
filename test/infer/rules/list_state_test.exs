defmodule Infer.Rules.ListStateTest do
  use Infer.Test.DataCase

  defmodule TaskRules do
    use Infer.Rules, for: Task

    infer completed?: false, when: %{completed_at: nil}
    infer completed?: true
  end

  defmodule Rules do
    use Infer.Rules, for: List

    import_rules TaskRules

    infer archived?: true, when: %{archived_at: {:not, nil}}

    infer state: :archived, when: %{archived?: true}
    infer state: :in_progress, when: %{tasks: %{completed?: true}}
    infer state: :ready, when: %{tasks: %{}}
    infer state: :empty
  end

  test "returns state: :archived" do
    list = build(List, %{archived_at: DateTime.utc_now() |> DateTime.truncate(:second)})

    assert Infer.load!(list, :state, extra_rules: Rules) == :archived
  end

  test "returns state: :in_progress" do
    list = create(List, %{archived_at: nil, created_by: %{}})

    create(Task, %{
      list: list,
      completed_at: DateTime.utc_now() |> DateTime.truncate(:second),
      created_by: list.created_by
    })

    create(Task, %{
      list: list,
      completed_at: nil,
      created_by: list.created_by
    })

    assert Infer.load!(list, :state, extra_rules: Rules) == :in_progress
  end

  test "returns state: :ready" do
    list = create(List, %{archived_at: nil, created_by: %{}})

    1..2
    |> Enum.each(fn _i ->
      create(Task, %{
        list: list,
        completed_at: nil,
        created_by: list.created_by
      })
    end)

    assert Infer.load!(list, :state, extra_rules: Rules) == :ready
  end

  test "returns state: :empty" do
    list = create(List, %{archived_at: nil, created_by: %{}})

    assert Infer.load!(list, :state, extra_rules: Rules) == :empty
  end
end
