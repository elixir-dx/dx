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

  def fetch(map, subset, eval) when is_map(subset) do
    eval.loader.lookup(eval.cache, {:subset, map, subset}, false)
  end

  defp fetch_list(list, data_reqs_by_index, eval) do
    list
    |> Enum.with_index()
    |> Enum.reduce([], fn {elem, index}, acc ->
      data_req = Map.get(data_reqs_by_index, index, %{})
      result = fetch(elem, data_req, eval)
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
