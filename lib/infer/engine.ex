defmodule Infer.Engine do
  @moduledoc """
  Encapsulates the main functionality of working with rules.
  """

  alias Infer.{Result, Rule, Util}
  alias Infer.Evaluation, as: Eval

  @doc """
  Returns the result of evaluating a predicate.
  """
  @spec resolve_predicate(atom(), struct(), Eval.t()) :: Result.v()
  def resolve_predicate(predicate, %type{} = subject, %Eval{} = eval) do
    predicate
    |> Util.rules_for_predicate(type, eval)
    |> match_rules(subject, eval)
  end

  @doc """
  Returns the result of evaluating a field or predicate.
  """
  @spec resolve(atom(), map(), Eval.t()) :: Result.v()
  def resolve(field_or_predicate, %type{} = subject, %Eval{} = eval) do
    field_or_predicate
    |> Util.rules_for_predicate(type, eval)
    |> case do
      [] -> fetch(subject, field_or_predicate, eval)
      rules -> match_rules(rules, subject, eval)
    end
  end

  def resolve(field, map, %Eval{} = eval) do
    fetch(map, field, eval)
  end

  def resolve_source(field_or_predicate, eval) when is_atom(field_or_predicate) do
    resolve(field_or_predicate, eval.root_subject, eval)
  end

  def resolve_source(list, _eval) when is_list(list) do
    Result.ok(list)
  end

  def resolve_source(other, eval) do
    map_result(other, eval)
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

    Result.find(rules, &match_next(&1, record, eval), &rule_result(&1, &2, record, eval))
  end

  defp match_next({condition, val}, record, eval) do
    result = evaluate_condition(condition, record, eval)

    if eval.debug? do
      subject_info =
        case record do
          %type{} -> type
          other -> other
        end

      result_info =
        case result do
          {:ok, true, _} -> inspect(val)
          {:ok, other, _} -> inspect(other, pretty: true)
          other -> inspect(other, pretty: true)
        end

      IO.puts(
        "[infer] #{inspect(subject_info)} is #{result_info} for " <>
          inspect(condition, pretty: true)
      )
    end

    result
  end

  # Traverses the assigns of a rule, replacing special tuples
  #   - `{:ref, path}` with the predicate or field value found at the given path
  #   - `{fun/n, arg_1, ..., arg_n}` with the result of calling the given function
  #       with the given arguments (which in turn can be special tuples)
  #   - `{:bound, :var}` - with a corresponding matching `{:bind, :var}`
  #   - `{:bound, :var, default}` - same with default
  defp rule_result({_condition, val}, binds, subject, eval) do
    eval = %{eval | root_subject: subject, binds: binds}

    val
    |> map_result(eval)
  end

  defp map_result(%type{} = struct, eval) do
    struct
    |> Map.from_struct()
    |> map_result(eval)
    |> Result.transform(&struct(type, &1))
  end

  defp map_result(map, eval) when is_map(map) do
    Result.map_values(map, &map_result(&1, eval))
  end

  defp map_result(list, eval) when is_list(list) do
    Result.map(list, &map_result(&1, eval))
  end

  defp map_result({:ref, [:args | path]}, eval) do
    eval.args
    |> resolve_path(path, eval)
  end

  defp map_result({:ref, path}, eval) do
    eval.root_subject
    |> resolve_path(List.wrap(path), eval)
  end

  defp map_result({fun, args}, eval) when is_function(fun) do
    args
    |> List.wrap()
    |> Result.map(&map_result(&1, eval))
    |> Result.transform(&apply(fun, &1))
  end

  defp map_result({query_type, type, conditions, opts}, eval)
       when query_type in [:query_one, :query_first, :query_all] do
    conditions
    |> Result.map_keyword_values(&map_result(&1, eval))
    |> Result.then(fn conditions ->
      eval.loader.lookup(eval.cache, {query_type, type, conditions, opts})
    end)
  end

  # add empty opts when omitted
  defp map_result({query_type, type, conditions}, eval)
       when query_type in [:query_one, :query_first, :query_all] do
    map_result({query_type, type, conditions, []}, eval)
  end

  defp map_result({:map, source, each_key, each_val}, eval) when is_atom(each_key) do
    resolve_source(source, eval)
    |> Result.then(fn subjects ->
      Result.map(subjects, fn subject ->
        eval = %{eval | binds: %{each_key => subject}}

        map_result(each_val, eval)
      end)
    end)
  end

  defp map_result({:map, source, condition, each_val}, eval) do
    resolve_source(source, eval)
    |> Result.then(fn subjects ->
      Result.filter_map(
        subjects,
        &evaluate_condition(condition, &1, eval),
        fn _subject, binds ->
          eval = %{eval | binds: binds}

          map_result(each_val, eval)
        end
      )
    end)
  end

  defp map_result({:map, source, each_val}, eval) do
    resolve_source(source, eval)
    |> Result.then(fn subjects ->
      Result.map(subjects, fn
        nil ->
          Result.ok(nil)

        subject ->
          case each_val do
            predicate when is_atom(predicate) ->
              resolve(predicate, subject, eval)

            other ->
              eval = %{eval | root_subject: subject}
              map_result(other, eval)
          end
      end)
    end)
  end

  defp map_result({:filter, source, condition}, eval) do
    resolve_source(source, eval)
    |> Result.then(fn subjects ->
      Result.filter_map(subjects, &evaluate_condition(condition, &1, eval))
    end)
  end

  defp map_result({:count, source, conditions}, eval) do
    resolve_source(source, eval)
    |> Result.then(fn subjects ->
      Result.count(subjects, fn
        nil ->
          Result.ok(false)

        subject ->
          case conditions do
            predicate when is_atom(predicate) ->
              resolve(predicate, subject, eval)

            condition when is_map(condition) or is_list(condition) ->
              evaluate_condition(condition, subject, eval)

            other ->
              map_result(other, eval)
          end
      end)
    end)
  end

  defp map_result({:count_while, source, conditions}, eval) do
    resolve_source(source, eval)
    |> Result.then(fn subjects ->
      Result.count_while(subjects, fn
        nil ->
          Result.ok(false)

        subject ->
          case conditions do
            predicate when is_atom(predicate) ->
              resolve(predicate, subject, eval)

            condition when is_map(condition) or is_list(condition) ->
              evaluate_condition(condition, subject, eval)

            other ->
              map_result(other, eval)
          end
      end)
    end)
  end

  defp map_result({:bound, key, default}, eval) do
    case Map.fetch(eval.binds, key) do
      {:ok, value} -> Result.ok(value)
      :error -> Result.ok(default)
    end
  end

  defp map_result({:bound, key}, eval) do
    case Map.fetch(eval.binds, key) do
      {:ok, value} ->
        Result.ok(value)

      :error ->
        {:error,
         %KeyError{message: "{:bound, #{inspect(key)}} used in value but not bound in condition."}}
    end
  end

  defp map_result(other, _eval), do: Result.ok(other)

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
    |> resolve_path(path, eval)
    |> Result.then(&evaluate_condition(&1, subject, eval))
  end

  defp evaluate_condition({:ref, path}, subject, %Eval{} = eval) do
    eval.root_subject
    |> resolve_path(List.wrap(path), eval)
    |> Result.then(&evaluate_condition(&1, subject, eval))
  end

  defp evaluate_condition({:bind, key, condition}, subject, eval) do
    evaluate_condition(condition, subject, eval)
    |> Result.bind(key, subject)
  end

  defp evaluate_condition({:args, sub_condition}, subject, %Eval{root_subject: subject} = eval) do
    evaluate_condition(sub_condition, eval.args, eval)
  end

  defp evaluate_condition({{:ref, path}, conditions}, subject, eval) when is_map(subject) do
    eval.root_subject
    |> resolve_path(List.wrap(path), eval)
    |> Result.then(&evaluate_condition(conditions, &1, eval))
  end

  defp evaluate_condition({key, conditions}, subject, eval) when is_map(subject) do
    resolve(key, subject, eval)
    |> Result.then(&evaluate_condition(conditions, &1, eval))
  end

  defp evaluate_condition(%type{} = other, %type{} = subject, _eval) do
    if Util.Module.has_function?(type, :compare, 2) do
      Result.ok(type.compare(subject, other) == :eq)
    else
      Result.ok(subject == other)
    end
  end

  defp evaluate_condition(predicate, %_type{} = subject, eval)
       when is_atom(predicate) and predicate not in [nil, true, false] do
    resolve(predicate, subject, eval)
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
        eval.loader.lookup(eval.cache, {:assoc, map, key})

      other ->
        Result.ok(other)
    end
  rescue
    e in KeyError -> {:error, e}
  end

  defp resolve_path(val, [], _eval), do: Result.ok(val)
  defp resolve_path(nil, _path, _eval), do: Result.ok(nil)

  defp resolve_path(list, path, eval) when is_list(list) do
    Result.map(list, &resolve_path(&1, path, eval))
  end

  defp resolve_path(map, [keys], eval) when is_list(keys) do
    resolve_path(map, [Util.Map.zip(keys, keys)], eval)
  end

  defp resolve_path(map, [keymap], eval) when is_map(keymap) do
    Result.map_values(keymap, &resolve_path(map, List.wrap(&1), eval))
  end

  defp resolve_path(map, [key | path], eval) do
    resolve(key, map, eval)
    |> Result.then(&resolve_path(&1, path, eval))
  end
end
