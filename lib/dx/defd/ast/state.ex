defmodule Dx.Defd.Ast.State do
  @moduledoc false

  @doc """
  Pass in state overrides (fixed values or update functions)
  that are reverted after the function call.
  """
  def pass_in(state, overrides, fun) do
    keys = keys(overrides)
    originals = Map.take(state, keys)

    {returned_ast, returned_state} =
      state
      |> merge_or_update(overrides)
      |> fun.()

    new_state =
      Enum.reduce(keys, returned_state, fn key, state ->
        case Map.fetch(originals, key) do
          {:ok, original_val} -> Map.put(state, key, original_val)
          :error -> Map.delete(state, key)
        end
      end)

    {returned_ast, new_state}
  end

  defp keys(enum), do: Enum.map(enum, fn {key, _} -> key end)

  @doc """
  Pass in state overrides (fixed values or update functions)
  """
  def merge_or_update(state, overrides) do
    Enum.reduce(overrides, state, fn
      {key, fun}, state when is_function(fun, 1) -> Map.update!(state, key, fun)
      {key, val}, state -> Map.put(state, key, val)
    end)
  end
end
