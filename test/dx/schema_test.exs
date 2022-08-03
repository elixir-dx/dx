defmodule Dx.SchemaTest do
  use Dx.Test.DataCase

  doctest Dx.Schema, import: true

  describe "expand_mapping" do
    defmodule TaskRules do
      use Dx.Rules, for: Task

      infer completed?: false, when: %{completed_at: nil}
      infer completed?: true
    end

    defmodule Rules do
      use Dx.Rules, for: List

      import_rules TaskRules

      infer archived?: true, when: %{archived_at: {:not, nil}}
      infer archived?: false

      infer state: :archived, when: %{archived?: true}
      infer state: :in_progress, when: %{tasks: %{completed?: true}}
      infer state: :ready, when: %{tasks: %{}}
      infer state: :empty
    end

    setup do
      eval = Dx.Evaluation.from_options(extra_rules: Rules)

      [eval: eval]
    end

    test "produces correct plan", %{eval: eval} do
      {expanded, type} = Dx.Schema.expand_result({:ref, :state}, List, eval)

      assert expanded ==
               {:ref,
                [
                  {:predicate, %{name: :state},
                   [
                     archived: {
                       {:predicate, %{name: :archived?},
                        [
                          {true, {{:field, :archived_at}, {:not, nil}}},
                          {false, true}
                        ]},
                       true
                     },
                     in_progress: {
                       {:assoc, :many, Task, %{name: :tasks, ordered: false, unique: true}},
                       {
                         {:predicate, %{name: :completed?},
                          [
                            {false, {{:field, :completed_at}, nil}},
                            {true, true}
                          ]},
                         true
                       }
                     },
                     ready: {
                       {:assoc, :many, Task, %{name: :tasks, ordered: false, unique: true}},
                       true
                     },
                     empty: true
                   ]}
                ]}

      assert type == {:atom, [:archived, :in_progress, :ready, :empty]}
    end

    test "combines booleans", %{eval: eval} do
      {_expanded, type} = Dx.Schema.expand_result({:ref, :archived?}, List, eval)

      assert type == :boolean
    end

    test "has_many type", %{eval: eval} do
      {_expanded, type} = Dx.Schema.expand_result({:ref, :tasks}, List, eval)

      assert type == {:array, Task}
    end

    test "belongs_to type", %{eval: eval} do
      {_expanded, type} = Dx.Schema.expand_mapping(:list, Task, eval)

      assert type == [List, nil]
    end
  end
end
