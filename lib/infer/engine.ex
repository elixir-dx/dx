defmodule Infer.Engine do
  @moduledoc """
  Encapsulates the main functionality of working with rules.
  """

  alias Infer.{Result, Rule, Util}
  alias Infer.Evaluation, as: Eval

  @doc """
  Entry point for this module
  """
  @spec resolve_predicate(atom(), struct(), Eval.t()) :: Result.v()
  def resolve_predicate(predicate, %type{} = subject, %Eval{} = eval) do
    predicate
    |> Util.rules_for_predicate(type, eval)
    |> match_rules(subject, eval)
  end

  # receives a list of rules for a predicate, returns a value result (`t:Result.v()`).
  #
  # goes through the rules, evaluating the condition of each, which can yield one of
  #   - {:ok, false} -> skip to next rule
  #   - {:ok, true} -> stop here and return rule assigns
  #   - {:not_loaded, data_reqs} -> collect and move on, return {:not_loaded, all_data_reqs} at the end
  #   - {:error, e} -> return right away
  @spec match_rules(list(Rule.t()), any(), Eval.t()) :: Result.v()
  defp match_rules(rules, record, %Eval{} = eval) do
    eval = %{eval | root_subject: record}

    Result.find(rules, &match_next(&1, record, eval), & &1.val)
  end

  defp match_next(rule, record, eval) do
    result = evaluate_condition(rule.when, record, eval)

    if eval.debug? do
      subject_info =
        case record do
          %type{} -> type
          other -> other
        end

      result_info =
        case result do
          {:ok, true, _} -> "#{inspect(rule.key)} => #{inspect(rule.val)}"
          {:ok, other, _} -> inspect(other, pretty: true)
          other -> inspect(other, pretty: true)
        end

      IO.puts(
        "[infer] #{inspect(subject_info)} is #{result_info} for " <>
          inspect(rule.when, pretty: true)
      )
    end

    result
  end

  @spec evaluate_condition(any(), any(), Eval.t()) :: Result.b()
  defp evaluate_condition(condition, subjects, eval) when is_list(subjects) do
    Result.any?(subjects, &evaluate_condition(condition, &1, eval))
  end

  defp evaluate_condition(conditions, subject, eval) when is_list(conditions) do
    Result.any?(conditions, &evaluate_condition(&1, subject, eval))
  end

  defp evaluate_condition({:not, condition}, subject, %Eval{} = eval) do
    evaluate_condition(condition, subject, eval)
    |> Result.transform(&not/1)
  end

  defp evaluate_condition({:ref, [:args | path]}, subject, %Eval{} = eval) do
    eval.args
    |> get_in_path(path, eval)
    |> Result.then(&evaluate_condition(&1, subject, eval))
  end

  defp evaluate_condition({:ref, path}, subject, %Eval{} = eval) do
    eval.root_subject
    |> get_in_path(path, eval)
    |> Result.then(&evaluate_condition(&1, subject, eval))
  end

  defp evaluate_condition({:args, sub_condition}, subject, %Eval{root_subject: subject} = eval) do
    evaluate_condition(sub_condition, eval.args, eval)
  end

  defp evaluate_condition({key, sub_condition}, %type{} = subject, %Eval{} = eval) do
    key
    |> Util.rules_for_predicate(type, eval)
    |> case do
      [] ->
        case Map.get(subject, key) do
          %Ecto.Association.NotLoaded{} ->
            eval.loader.lookup(eval.cache, :assoc, subject, key)
            |> Result.then(&evaluate_condition(sub_condition, &1, eval))

          value ->
            evaluate_condition(sub_condition, value, eval)
        end

      rules ->
        match_rules(rules, subject, eval)
        |> Result.then(&evaluate_condition(sub_condition, &1, eval))
    end
  end

  defp evaluate_condition({key, conditions}, subject, eval) when is_map(subject) do
    fetch(subject, key, eval)
    |> Result.then(&evaluate_condition(conditions, &1, eval))
  end

  defp evaluate_condition(%type{} = other, %type{} = subject, _eval) do
    if Util.Module.has_function?(type, :compare, 2) do
      Result.ok(type.compare(subject, other) == :eq)
    else
      Result.ok(subject == other)
    end
  end

  defp evaluate_condition(predicate, %type{} = subject, eval)
       when is_atom(predicate) and not is_nil(predicate) do
    predicate
    |> Util.rules_for_predicate(type, eval)
    |> case do
      [] -> fetch(subject, predicate, eval)
      rules -> match_rules(rules, subject, eval)
    end
    |> Result.transform(&(&1 == true))
  end

  defp evaluate_condition(conditions, subject, eval) when is_map(conditions) do
    Result.all?(conditions, &evaluate_condition(&1, subject, eval))
  end

  defp evaluate_condition(other, subject, _eval) do
    Result.ok(subject == other)
  end

  defp fetch(map, key, eval) do
    case Map.fetch!(map, key) do
      %Ecto.Association.NotLoaded{} ->
        eval.loader.lookup(eval.cache, :assoc, map, key)

      other ->
        Result.ok(other)
    end
  rescue
    e in KeyError -> {:error, e}
  end

  defp get_in_path(val, [], _eval), do: Result.ok(val)
  defp get_in_path(nil, _path, _eval), do: Result.ok(nil)

  defp get_in_path(map, [key | path], eval) do
    fetch(map, key, eval)
    |> Result.then(&get_in_path(&1, path, eval))
  end
end
