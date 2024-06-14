defmodule Dx.Defd.Runtime do
  alias Dx.Defd.Result

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
