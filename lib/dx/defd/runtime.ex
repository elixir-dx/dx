# Functions inserted by the compiler to be run at runtime (not compile-time)
defmodule Dx.Defd.Runtime do
  @moduledoc false

  alias Dx.Defd.Result
  alias Dx.Defd.Util

  def maybe_call_defd(module, fun_name, args, eval) do
    Code.ensure_loaded(module)
    defd_name = Util.defd_name(fun_name)
    arity = length(args)

    if function_exported?(module, defd_name, arity) do
      apply(module, defd_name, args ++ [eval])
    else
      {:ok, apply(module, fun_name, args)}
    end
  end

  def fetch(subject, data_reqs, _eval) when data_reqs == %{} do
    {:ok, subject}
  end

  def fetch(list, data_reqs, eval) when is_list(list) do
    if elem_reqs = data_reqs[:__list__] do
      fetch_list(list, elem_reqs, eval)
    else
      {:ok, list}
    end
  end

  def fetch(tuple, data_reqs, eval) when is_tuple(tuple) do
    if elem_reqs = data_reqs[{:__tuple__, tuple_size(tuple)}] do
      tuple
      |> Tuple.to_list()
      |> fetch_list(elem_reqs, eval)
      |> Result.transform(&List.to_tuple/1)
    else
      {:ok, tuple}
    end
  end

  def fetch(%Dx.Scope{} = scope, data_reqs, eval) do
    Dx.Scope.lookup(scope, eval)
    |> Result.then(&fetch(&1, data_reqs, eval))
  end

  def fetch(%type{} = struct, %{} = data_reqs, eval) when data_reqs != %{} do
    assocs =
      if function_exported?(type, :__schema__, 1), do: type.__schema__(:associations), else: []

    # for all key-value pairs in current map ...
    Enum.reduce_while(data_reqs, {:ok, struct}, fn {field, data_reqs}, acc ->
      case {Map.fetch(struct, field), field in assocs} do
        {{:ok, %Dx.Scope{} = scope}, _} ->
          result =
            Dx.Scope.lookup(scope, eval)
            |> Result.then(fn loaded_value ->
              fetch(loaded_value, data_reqs, eval)
              |> Result.transform(&Map.put(struct, field, &1))
            end)

          Result.merge(acc, result)

        {{:ok, val}, true} ->
          result =
            fetch(struct, val, field, eval)
            |> Result.then(fn loaded_value ->
              fetch(loaded_value, data_reqs, eval)
              |> Result.transform(&Map.put(struct, field, &1))
            end)

          Result.merge(acc, result)

        _else ->
          {:cont, acc}
      end
    end)
  end

  def fetch(map, data_reqs, eval) when is_map(map) and is_map(data_reqs) do
    # for all key-value pairs in current map ...
    Enum.reduce_while(data_reqs, {:ok, map}, fn {field, data_reqs}, acc ->
      case Map.fetch(map, field) do
        {:ok, %Dx.Scope{} = scope} ->
          result =
            Dx.Scope.lookup(scope, eval)
            |> Result.then(fn loaded_value ->
              fetch(loaded_value, data_reqs, eval)
              |> Result.transform(&Map.put(map, field, &1))
            end)

          Result.merge(acc, result)

        {:ok, val} ->
          result =
            fetch(val, data_reqs, eval)
            |> Result.then(fn loaded_value ->
              fetch(loaded_value, data_reqs, eval)
              |> Result.transform(&Map.put(map, field, &1))
            end)

          Result.merge(acc, result)

        _else ->
          {:cont, acc}
      end
    end)
  end

  def fetch(other, _data_reqs, _eval) do
    {:ok, other}
  end

  defp fetch_list(list, data_reqs_by_index, eval) do
    list
    |> Enum.with_index()
    |> Enum.reduce([], fn {elem, index}, acc ->
      data_req = Map.get(data_reqs_by_index, index, %{})
      result = elem |> fetch(data_req, eval)
      [result | acc]
    end)
    |> Result.collect_reverse()
  end

  def fetch(map, val, key, eval) do
    case val do
      %Ecto.Association.NotLoaded{} ->
        eval.loader.lookup(eval.cache, {:assoc, map, key}, false)

      other ->
        Result.ok(other)
    end
  end

  @doc "Recursively loads `Dx.Scope`s at runtime"
  def load_scopes(%Dx.Scope{} = scope, eval) do
    Dx.Scope.lookup(scope, eval)
  end

  def load_scopes(%type{} = struct, eval) do
    struct
    |> Map.from_struct()
    |> load_scopes(eval)
    |> Result.transform(&struct(type, &1))
  end

  def load_scopes(map, eval) when is_map(map) do
    Result.map(map, fn {key, val} ->
      load_scopes(key, eval)
      |> Result.then(fn key ->
        load_scopes(val, eval)
        |> Result.then(fn val ->
          {:ok, {key, val}}
        end)
      end)
    end)
    |> Result.transform(&Map.new/1)
  end

  def load_scopes(list, eval) when is_list(list) do
    Result.map(list, &load_scopes(&1, eval))
  end

  def load_scopes(tuple, eval) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> load_scopes(eval)
    |> Result.transform(&List.to_tuple/1)
  end

  def load_scopes(other, _eval), do: Result.ok(other)

  @doc "Recursively loads `Dx.Scope`s and unwraps `Dx.Fn`s at runtime"
  def finalize(%Dx.Scope{} = scope, eval) do
    Dx.Scope.lookup(scope, eval)
  end

  def finalize(%Dx.Defd.Fn{ok_fun: fun}, _eval) do
    {:ok, fun}
  end

  def finalize(%type{} = struct, eval) do
    struct
    |> Map.from_struct()
    |> finalize(eval)
    |> Result.transform(&struct(type, &1))
  end

  def finalize(map, eval) when is_map(map) do
    Result.map(map, fn {key, val} ->
      finalize(key, eval)
      |> Result.then(fn key ->
        finalize(val, eval)
        |> Result.then(fn val ->
          {:ok, {key, val}}
        end)
      end)
    end)
    |> Result.transform(&Map.new/1)
  end

  def finalize(list, eval) when is_list(list) do
    Result.map(list, &finalize(&1, eval))
  end

  def finalize(tuple, eval) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> finalize(eval)
    |> Result.transform(&List.to_tuple/1)
  end

  def finalize(other, _eval), do: Result.ok(other)
end
