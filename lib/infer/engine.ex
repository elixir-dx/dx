defmodule Infer.Engine do
  @moduledoc """
  Encapsulates the main functionality of working with rules.
  """

  alias Infer.{Result, Util}
  alias Infer.Evaluation, as: Eval

  @loader Infer.Loaders.Dataloader

  @doc """
  Entry point for this module
  """
  def resolve_predicate(predicate, %type{} = subject, opts \\ []) do
    eval = Eval.from_options(opts)

    predicate
    |> Util.rules_for_predicate(type, eval)
    |> match_rules(subject, eval)
  end

  # receives a list of rules for a predicate,
  # returns one of
  #   - {:ok, result}
  #   - {:not_loaded, data_reqs}
  #   - {:error, e}
  #
  # goes through rules, evaluate condition for each, which can yield one of
  #   - {:ok, false} -> skip to next rule
  #   - {:ok, true} -> stop here and return rule assigns
  #   - {:not_loaded, data_reqs} -> collect and move on, return {:not_loaded, all_data_reqs} at the end
  #   - {:error, e} -> return right away
  defp match_rules(rules, record, %Eval{} = eval) do
    eval = %{eval | root_subject: record}

    Result.first(rules, &match_next(&1, record, eval), & &1.val)
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
          {:ok, true} -> "#{inspect(rule.key)} => #{inspect(rule.val)}"
          {:ok, other} -> inspect(other, pretty: true)
          other -> inspect(other, pretty: true)
        end

      IO.puts(
        "[infer] #{inspect(subject_info)} is #{result_info} for #{inspect(rule.when, pretty: true)}"
      )
    end

    result
  end

  defp evaluate_condition(condition, subjects, eval) when is_list(subjects) do
    Result.any?(subjects, &evaluate_condition(condition, &1, eval))
  end

  defp evaluate_condition(conditions, subject, eval) when is_list(conditions) do
    Result.any?(conditions, &evaluate_condition(&1, subject, eval))
  end

  defp evaluate_condition({:not, condition}, subject, %Eval{} = eval) do
    case evaluate_condition(condition, subject, eval) do
      {:ok, true} -> {:ok, false}
      {:ok, false} -> {:ok, true}
      {:ok, other} -> raise ArgumentError, "Boolean expected, got #{inspect(other)}"
      other -> other
    end
  end

  defp evaluate_condition({:ref, [:args | path]}, subject, %Eval{} = eval) do
    eval.args
    |> get_in_path(path)
    |> evaluate_condition(subject, eval)
  end

  defp evaluate_condition({:ref, path}, subject, %Eval{} = eval) do
    eval.root_subject
    |> get_in_path(path)
    |> case do
      {:ok, result} -> result |> evaluate_condition(subject, eval)
      other -> other
    end
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
            data_reqs = @loader.condition_data_requirements(:assoc, subject, key)
            {:not_loaded, data_reqs}

          value ->
            evaluate_condition(sub_condition, value, eval)
        end

      rules ->
        case match_rules(rules, subject, eval) do
          {:ok, result} -> evaluate_condition(sub_condition, result, eval)
          other -> other
        end
    end
  end

  defp evaluate_condition({key, conditions}, subject, eval) when is_map(subject) do
    case fetch(subject, key) do
      {:ok, subject} -> evaluate_condition(conditions, subject, eval)
      other -> other
    end
  end

  defp evaluate_condition(%type{} = other, %type{} = subject, _eval) do
    if Util.Module.has_function?(type, :compare, 2) do
      {:ok, type.compare(subject, other) == :eq}
    else
      {:ok, subject == other}
    end
  end

  defp evaluate_condition(predicate, %type{} = subject, eval)
       when is_atom(predicate) and not is_nil(predicate) do
    predicate
    |> Util.rules_for_predicate(type, eval)
    |> case do
      [] -> fetch(subject, predicate)
      rules -> match_rules(rules, subject, eval)
    end
    |> case do
      {:ok, result} -> {:ok, result == true}
      other -> other
    end
  end

  defp evaluate_condition(conditions, subject, eval) when is_map(conditions) do
    Result.all?(conditions, &evaluate_condition(&1, subject, eval))
  end

  defp evaluate_condition(other, subject, _eval) do
    {:ok, subject == other}
  end

  defp fetch(map, key) do
    case Map.fetch!(map, key) do
      %Ecto.Association.NotLoaded{} ->
        data_reqs = @loader.path_data_requirements(:assoc, map, key)
        {:not_loaded, data_reqs}

      other ->
        {:ok, other}
    end
  rescue
    e in KeyError -> {:error, e}
  end

  defp get_in_path(val, []), do: {:ok, val}
  defp get_in_path(nil, _path), do: {:ok, nil}

  defp get_in_path(map, [key | path]) do
    case fetch(map, key) do
      {:ok, val} -> val |> get_in_path(path)
      other -> other
    end
  end
end
