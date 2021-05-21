defmodule Infer.Engine do
  @moduledoc """
  Encapsulates the main functionality of working with rules.
  """

  alias Infer.{Rule, Util}
  alias Infer.Evaluation, as: Eval

  @loader Infer.Loaders.Dataloader

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

    Enum.reduce_while(rules, {:ok, false}, &match_next(&2, &1, record, eval))
    |> case do
      {:ok, false} -> {:ok, nil}
      {:ok, %Rule{} = rule} -> {:ok, rule.val}
      other -> other
    end
  end

  defp match_next(acc, rule, record, eval) do
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

    case combine(acc, result, :first) do
      {:halt, {:ok, true}} -> {:halt, {:ok, rule}}
      other -> other
    end
  end

  # Passed to `Enum.reduce_while/3` to combine 2 results on each call
  #
  # Result is either
  #   - `{:error, e}`
  #   - `{:not_loaded, data_reqs}` if the result could not be determined without loading more data
  #   - `{:ok, result}` depending on third arg (see below)
  #
  # Third arg can be either
  #   - `:any?` (logical `OR`)
  #   - `:all?` (logical `AND`)
  #   - `:first` to return `{:ok, result}` on first match
  #
  # `{:not_loaded, all_reqs}` is only returned if the data is really needed.
  #
  # For example, using `:all?` with 3 conditions A, B and C, where
  #   - A is `{:ok, true}`
  #   - B is `{:not_loaded, data_reqs}`
  #   - C is `{:ok, false}`
  #
  # The overall result is `{:ok, false}`.
  # While B would need more data to be loaded, C can already determind and is `false`,
  # so and any additional data loaded will not change that.
  #
  # Another example, using `:first` with 5 conditions A, B, C, D and E, where
  #   - A is `{:ok, false}`
  #   - B is `{:not_loaded, data_reqs1}`
  #   - C is `{:not_loaded, data_reqs2}`
  #   - D is `{:ok, true}`
  #   - E is `{:not_loaded, data_reqs3}`
  #
  # The overall result is `{:not_loaded, data_reqs1 + data_reqs2}`.
  # While D can already be determined and is `{:ok, true}`, B and C come first and need more data
  # to be loaded, so they can be determined and returned if either is `{:ok, true}` first.
  # All data requirements that might be needed are returned together in the result (those of B and C),
  # while those of E can be ruled out, as D already returns `{:ok, true}` and comes first.
  defp combine(_acc, {:error, e}, _), do: {:halt, {:error, e}}
  defp combine({:not_loaded, r1}, {:not_loaded, r2}, _), do: {:cont, {:not_loaded, r1 ++ r2}}
  defp combine(_acc, {:not_loaded, reqs}, _), do: {:cont, {:not_loaded, reqs}}
  defp combine({:not_loaded, reqs}, _, :first), do: {:cont, {:not_loaded, reqs}}

  defp combine(_acc, {:ok, true}, :any?), do: {:halt, {:ok, true}}
  defp combine(_acc, {:ok, true}, :first), do: {:halt, {:ok, true}}
  defp combine(_acc, {:ok, false}, :all?), do: {:halt, {:ok, false}}
  defp combine(acc, {:ok, false}, :any?), do: {:cont, acc}
  defp combine(acc, {:ok, false}, :first), do: {:cont, acc}
  defp combine(acc, {:ok, true}, :all?), do: {:cont, acc}

  defp evaluate_condition(condition, subjects, eval) when is_list(subjects) do
    Enum.reduce_while(subjects, {:ok, false}, fn subject, acc ->
      result = evaluate_condition(condition, subject, eval)
      combine(acc, result, :any?)
    end)
  end

  defp evaluate_condition(conditions, subject, eval) when is_list(conditions) do
    Enum.reduce_while(conditions, {:ok, false}, fn condition, acc ->
      result = evaluate_condition(condition, subject, eval)
      combine(acc, result, :any?)
    end)
  end

  defp evaluate_condition({:not, condition}, subject, %Eval{} = eval) do
    case evaluate_condition(condition, subject, eval) do
      {:ok, true} -> {:ok, false}
      {:ok, false} -> {:ok, true}
      {:ok, other} -> raise ArgumentError, "Boolean expected, got #{inspect(other)}"
      other -> other
    end
  end

  defp evaluate_condition({:ref, path}, subject, %Eval{} = eval) do
    eval.root_subject
    |> get_in_path(path)
    |> case do
      {:ok, result} -> result |> evaluate_condition(subject, eval)
      other -> other
    end
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
    Enum.reduce_while(conditions, {:ok, true}, fn condition, acc ->
      result = evaluate_condition(condition, subject, eval)
      combine(acc, result, :all?)
    end)
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
