defmodule Infer.Engine do
  @moduledoc """
  Encapsulates the main functionality of working with rules.
  """

  alias Infer.Util

  def rules_for_predicate(predicate, type, opts) do
    extra_rules =
      opts
      |> Keyword.get(:extra_rules)
      |> List.wrap()
      |> Enum.flat_map(&rules_from_module/1)
      |> Enum.filter(&(&1.type in [nil, type]))

    (extra_rules ++ rules_from_module(type))
    |> Enum.filter(&(&1.key == predicate))
  end

  defp rules_from_module(type) do
    if Util.Module.has_function?(type, :infer_rules, 0) do
      type.infer_rules()
    else
      []
    end
  end

  def resolve_predicate(predicate, subject = %type{}, opts \\ []) do
    predicate
    |> rules_for_predicate(type, opts)
    |> match_rules(subject, opts)
  end

  defp match_rules([], _record, _opts), do: nil

  defp match_rules([rule | rules], record, opts) do
    result = evaluate_condition(rule.when, record, record, opts)

    if opts[:debug] do
      subject_info =
        case record do
          %type{} -> type
          other -> other
        end

      result_info = if result, do: "#{inspect(rule.key)} => #{inspect(rule.val)}", else: result

      IO.puts("[infer] #{inspect(subject_info)} is #{result_info} for #{inspect(rule.when)}")
    end

    if result do
      rule.val
    else
      match_rules(rules, record, opts)
    end
  end

  defp evaluate_condition(
         condition,
         %Ecto.Association.NotLoaded{} = not_loaded,
         _root_subject,
         _opts
       ) do
    raise "Association #{inspect(not_loaded.__field__)} is not loaded " <>
            "on #{inspect(not_loaded.__owner__)}. Cannot compare to: " <>
            inspect(condition)
  end

  defp evaluate_condition(condition, subjects, root_subject, opts) when is_list(subjects) do
    Enum.any?(subjects, &evaluate_condition(condition, &1, root_subject, opts))
  end

  defp evaluate_condition(conditions, subject, root_subject, opts) when is_list(conditions) do
    Enum.any?(conditions, &evaluate_condition(&1, subject, root_subject, opts))
  end

  defp evaluate_condition({:not, condition}, subject, root_subject, opts) do
    not evaluate_condition(condition, subject, root_subject, opts)
  end

  defp evaluate_condition({:ref, path}, subject, root_subject, opts) do
    root_subject
    |> get_in_path(path)
    |> evaluate_condition(subject, root_subject, opts)
  end

  defp evaluate_condition({key, sub_condition}, subject = %type{}, root_subject, opts) do
    key
    |> rules_for_predicate(type, opts)
    |> case do
      [] -> evaluate_condition(sub_condition, Map.get(subject, key), root_subject, opts)
      rules -> match_rules(rules, subject, opts)
    end
  end

  defp evaluate_condition(other = %type{}, subject = %type{}, _root_subject, _opts) do
    if Util.Module.has_function?(type, :compare, 2) do
      type.compare(subject, other) == :eq
    else
      subject == other
    end
  end

  defp evaluate_condition(predicate, subject = %type{}, _root_subject, opts)
       when is_atom(predicate) and not is_nil(predicate) do
    predicate
    |> rules_for_predicate(type, opts)
    |> case do
      [] -> Map.fetch!(subject, predicate) == true
      rules -> match_rules(rules, subject, opts) == true
    end
  end

  defp evaluate_condition(conditions, subject, root_subject, opts) when is_map(conditions) do
    Enum.all?(conditions, &evaluate_condition(&1, subject, root_subject, opts))
  end

  defp evaluate_condition(other, subject, _root_subject, _opts) do
    subject == other
  end

  defp get_in_path(val, []), do: val
  defp get_in_path(map, [key | path]), do: Map.get(map, key) |> get_in_path(path)
end
