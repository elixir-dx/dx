defmodule Dx.Ecto.QueryTest do
  use Dx.Test.DataCase, async: true

  alias Dx.Ecto.Query
  alias Dx.Test.Repo

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

    infer other_lists_by_creator: {:query_all, List, created_by_id: {:ref, :created_by_id}}
  end

  defp to_sql(query), do: Query.to_sql(Repo, query)

  test "condition on field" do
    query = Query.where(List, %{created_by_id: 7})

    assert to_sql(query) =~ "\"created_by_id\" = 7"
  end

  test "condition on association field" do
    query = Query.where(List, %{created_by: %{last_name: "Vega"}})

    assert to_sql(query) =~ "\"last_name\" = 'Vega'"
  end

  test "condition on predicate" do
    query = Query.where(List, %{state: :archived}, extra_rules: Rules)

    assert to_sql(query) =~ "WHERE (NOT (l0.\"archived_at\" IS NULL))"
  end

  test "condition on predicate list" do
    query = Query.where(List, %{state: [:archived]}, extra_rules: Rules)

    assert to_sql(query) =~ "WHERE (NOT (l0.\"archived_at\" IS NULL))"
  end

  test "condition on predicate values" do
    query = Query.where(List, %{state: [:archived, :in_progress]}, extra_rules: Rules)

    assert to_sql(query) =~
             ~s"""
             WHERE (exists(\
             (SELECT * FROM "tasks" AS st0 \
             WHERE (st0."list_id" = l0."id") \
             AND (NOT (st0."completed_at" IS NULL)))) \
             OR NOT (l0."archived_at" IS NULL))\
             """
  end

  test "condition on fallback predicate value" do
    query = Query.where(List, %{state: :empty}, extra_rules: Rules)

    assert to_sql(query) =~
             ~s"""
             WHERE (\
             NOT (exists((SELECT * FROM "tasks" AS st0 WHERE (st0."list_id" = l0."id")))) \
             AND (NOT (exists((SELECT * FROM "tasks" AS st0 WHERE (st0."list_id" = l0."id") AND (NOT (st0."completed_at" IS NULL))))) \
             AND NOT (NOT (l0."archived_at" IS NULL)))\
             )\
             """
  end

  test "condition on fallback predicate values" do
    query = Query.where(List, %{state: [:empty]}, extra_rules: Rules)

    assert to_sql(query) =~
             ~s"""
             WHERE (\
             NOT (exists((SELECT * FROM "tasks" AS st0 WHERE (st0."list_id" = l0."id")))) \
             AND (NOT (exists((SELECT * FROM "tasks" AS st0 WHERE (st0."list_id" = l0."id") AND (NOT (st0."completed_at" IS NULL))))) \
             AND NOT (NOT (l0."archived_at" IS NULL)))\
             )\
             """
  end

  test "condition on fallback and other predicate values" do
    query = Query.where(List, %{state: [:in_progress, :empty]}, extra_rules: Rules)

    assert to_sql(query) =~
             ~s"""
             WHERE (\
             (NOT (exists((SELECT * FROM "tasks" AS st0 WHERE (st0."list_id" = l0."id")))) \
             OR exists((SELECT * FROM "tasks" AS st0 WHERE (st0."list_id" = l0."id") AND (NOT (st0."completed_at" IS NULL))))) \
             AND NOT (NOT (l0."archived_at" IS NULL))\
             )\
             """
  end

  test "uses IN for multiple integer values" do
    query = Query.where(List, %{created_by_id: [1, 2, 3]})

    assert to_sql(query) =~ "l0.\"created_by_id\" = ANY('{1, 2, 3}')"
  end

  test "uses IN for multiple string values" do
    query = Query.where(List, %{created_by: %{last_name: ["Vega", "Medina"]}})

    assert to_sql(query) =~ "u1.\"last_name\" = ANY('{\"Vega\", \"Medina\"}')"
  end

  test "uses IN for simple values only" do
    query = Query.where(List, %{created_by_id: [1, 2, 3, {:ref, [:from_template_id]}]})

    assert to_sql(query) =~
             "(l0.\"created_by_id\" = l0.\"from_template_id\") OR l0.\"created_by_id\" = ANY('{1, 2, 3}')"
  end

  test "raises error only listing non-translatable conditions" do
    conditions = %{created_by_id: [1, 2, 3], other_lists_by_creator: %{}}

    errmsg = ~r/Could not translate some conditions to SQL:/

    assert_raise(Query.TranslationError, errmsg, fn ->
      Query.where(List, conditions, extra_rules: Rules)
    end)
  end
end
