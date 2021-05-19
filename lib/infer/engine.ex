defmodule Infer.Engine do
  @moduledoc """
  Encapsulates the main functionality of working with rules.
  """

  alias Infer.Util
  alias Infer.Evaluation, as: Eval

  def rules_for_predicate(predicate, type, %Eval{} = eval) do
    extra_rules =
      eval.extra_rules
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

  @doc """
  Entry point for this module
  """
  def resolve_predicate(predicate, %type{} = subject, opts \\ []) do
    # Hacky but effective way to make `:args` available on the subject level:
    # Remove `:args` from the options and put it directly into the subject
    # (circumventing Elixir struct field checks)
    {args, opts} = Keyword.pop(opts, :args, [])
    subject = Map.put(subject, :args, Map.new(args))

    eval = Eval.from_options(opts)

    predicate
    |> rules_for_predicate(type, eval)
    |> match_rules(subject, eval)
  end

  defp match_rules([], _record, _eval), do: nil

  defp match_rules([rule | rules], record, %Eval{} = eval) do
    eval = %{eval | root_subject: record}

    result = evaluate_condition(rule.when, record, eval)

    if eval.debug? do
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
      match_rules(rules, record, eval)
    end
  end

  defp evaluate_condition(
         condition,
         %Ecto.Association.NotLoaded{} = not_loaded,
         _eval
       ) do
    raise Infer.Error.NotLoaded,
      field: not_loaded.__field__,
      type: not_loaded.__owner__,
      cardinality: not_loaded.__cardinality__,
      condition: condition
  end

  defp evaluate_condition(condition, subjects, eval) when is_list(subjects) do
    Enum.any?(subjects, &evaluate_condition(condition, &1, eval))
  end

  defp evaluate_condition(conditions, subject, eval) when is_list(conditions) do
    Enum.any?(conditions, &evaluate_condition(&1, subject, eval))
  end

  defp evaluate_condition({:not, condition}, subject, %Eval{} = eval) do
    not evaluate_condition(condition, subject, eval)
  end

  defp evaluate_condition({:ref, path}, subject, %Eval{} = eval) do
    eval.root_subject
    |> get_in_path(path)
    |> evaluate_condition(subject, eval)
  end

  defp evaluate_condition({key, sub_condition}, %type{} = subject, %Eval{} = eval) do
    key
    |> rules_for_predicate(type, eval)
    |> case do
      [] ->
        evaluate_condition(sub_condition, Map.get(subject, key), eval)

      rules ->
        result = match_rules(rules, subject, eval)
        evaluate_condition(sub_condition, result, eval)
    end
  end

  defp evaluate_condition({key, conditions}, subject, eval) when is_map(subject) do
    subject = Map.fetch!(subject, key)
    evaluate_condition(conditions, subject, eval)
  end

  defp evaluate_condition(%type{} = other, %type{} = subject, _eval) do
    if Util.Module.has_function?(type, :compare, 2) do
      type.compare(subject, other) == :eq
    else
      subject == other
    end
  end

  defp evaluate_condition(predicate, %type{} = subject, eval)
       when is_atom(predicate) and not is_nil(predicate) do
    predicate
    |> rules_for_predicate(type, eval)
    |> case do
      [] -> Map.fetch!(subject, predicate) == true
      rules -> match_rules(rules, subject, eval) == true
    end
  end

  defp evaluate_condition(conditions, subject, eval) when is_map(conditions) do
    Enum.all?(conditions, &evaluate_condition(&1, subject, eval))
  end

  defp evaluate_condition(other, subject, _eval) do
    subject == other
  end

  defp get_in_path(val, []), do: val
  defp get_in_path(nil, _path), do: nil

  defp get_in_path(%Ecto.Association.NotLoaded{} = not_loaded, path) do
    raise Infer.Error.NotLoaded,
      field: not_loaded.__field__,
      type: not_loaded.__owner__,
      cardinality: not_loaded.__cardinality__,
      path: path
  end

  defp get_in_path(map, [key | path]), do: Map.fetch!(map, key) |> get_in_path(path)
end
