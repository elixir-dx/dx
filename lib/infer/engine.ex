defmodule Infer.Engine do
  @moduledoc """
  Encapsulates the main functionality of working with rules.
  """

  alias Infer.Util

  def rules_for_predicate(predicate, type) do
    if Util.Module.has_function?(type, :infer_rules, 0) do
      type.infer_rules()
      |> Enum.filter(&(&1.key == predicate))
    else
      []
    end
  end

  def resolve_predicate(predicate, subject = %type{}) do
    predicate
    |> rules_for_predicate(type)
    |> Infer.Engine.match_rules(subject)
  end

  def match_rules([], _record), do: nil

  def match_rules([rule | rules], record) do
    if evaluate_condition(rule.when, record, record) do
      rule.val
    else
      match_rules(rules, record)
    end
  end

  def evaluate_condition(condition, subjects, root_subject) when is_list(subjects) do
    Enum.any?(subjects, &evaluate_condition(condition, &1, root_subject))
  end

  def evaluate_condition(conditions, subject, root_subject) when is_list(conditions) do
    Enum.any?(conditions, &evaluate_condition(&1, subject, root_subject))
  end

  def evaluate_condition({:not, condition}, subject, root_subject) do
    not evaluate_condition(condition, subject, root_subject)
  end

  def evaluate_condition({:ref, path}, subject, root_subject) do
    root_subject
    |> get_in_path(path)
    |> evaluate_condition(subject, root_subject)
  end

  def evaluate_condition({key, sub_condition}, subject = %type{}, root_subject) do
    key
    |> rules_for_predicate(type)
    |> case do
      [] -> evaluate_condition(sub_condition, Map.get(subject, key), root_subject)
      rules -> match_rules(rules, subject)
    end
  end

  def evaluate_condition(other = %type{}, subject = %type{}, _root_subject) do
    if Util.Module.has_function?(type, :compare, 2) do
      type.compare(subject, other) == :eq
    else
      subject == other
    end
  end

  def evaluate_condition(predicate, subject = %type{}, _root_subject) when is_atom(predicate) do
    predicate
    |> rules_for_predicate(type)
    |> case do
      [] -> Map.fetch!(subject, predicate) == true
      rules -> match_rules(rules, subject) == true
    end
  end

  def evaluate_condition(conditions, subject, root_subject) when is_map(conditions) do
    Enum.all?(conditions, &evaluate_condition(&1, subject, root_subject))
  end

  def evaluate_condition(other, subject, _root_subject) do
    subject == other
  end

  defp get_in_path(val, []), do: val
  defp get_in_path(map, [key | path]), do: Map.get(map, key) |> get_in_path(path)
end
