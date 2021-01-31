defmodule Infer.Engine do
  @moduledoc """
  Encapsulates the main functionality of working with rules.
  """

  def rules_for_predicate(predicate, type) do
    type.infer_rules()
    |> Enum.filter(&(&1.key == predicate))
  end

  def resolve_predicate(predicate, subject = %type{}) do
    predicate
    |> rules_for_predicate(type)
    |> Infer.Engine.match_rules(subject)
  end

  def match_rules([], _record), do: nil

  def match_rules([rule | rules], record) do
    if evaluate_condition(rule.when, record) do
      rule.val
    else
      match_rules(rules, record)
    end
  end

  def evaluate_condition(conditions, subject) when is_list(conditions) do
    Enum.any?(conditions, &evaluate_condition(&1, subject))
  end

  def evaluate_condition(conditions, subject) when is_map(conditions) do
    Enum.all?(conditions, &evaluate_condition(&1, subject))
  end

  def evaluate_condition({key, sub_condition}, subject = %type{}) do
    key
    |> rules_for_predicate(type)
    |> case do
      [] -> evaluate_condition(sub_condition, Map.get(subject, key))
      rules -> match_rules(rules, subject)
    end
  end

  def evaluate_condition({:not, condition}, subject) do
    not evaluate_condition(condition, subject)
  end

  def evaluate_condition(predicate, subject = %type{}) when is_atom(predicate) do
    predicate
    |> rules_for_predicate(type)
    |> case do
      [] -> Map.fetch!(subject, predicate) == true
      rules -> match_rules(rules, subject) == true
    end
  end

  def evaluate_condition(other, subject) do
    subject == other
  end
end
