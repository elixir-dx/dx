defmodule Dx.Util.Map do
  @moduledoc """
  Utility functions for working with `Map` data structures.
  """

  def do_get_in(term, []), do: term

  def do_get_in(map, [h | t]) when is_map(map) do
    do_get_in(Map.fetch!(map, h), t)
  end

  def do_get_in(map, key) when is_map(map) do
    Map.fetch!(map, key)
  end

  def do_put_in(map, [field], val) when is_map(map) do
    Map.replace!(map, field, val)
  end

  def do_put_in(map, [h | t], val) when is_map(map) do
    Map.update!(map, h, &do_put_in(&1, t, val))
  end

  def do_put_in(map, field, val) when is_map(map) do
    Map.replace!(map, field, val)
  end

  @doc """
  Returns a `Map` with given keys and values zipped together

  ## Examples

      iex> [:d, :e, :b]
      ...> |> Dx.Util.Map.zip([8, 2, 3])
      %{d: 8, e: 2, b: 3}
  """
  def zip(keys, values) do
    do_zip(%{}, keys, values)
  end

  def do_zip(map, [key | keys], [value | values]) do
    map |> Map.put(key, value) |> do_zip(keys, values)
  end

  def do_zip(map, [], []) do
    map
  end

  @doc """
  Removes all keys from map1 that also exist in map2.

  ## Examples

      iex> Dx.Util.Map.subtract(%{a: 1, b: 2, c: 3}, %{a: 0, d: 4})
      %{b: 2, c: 3}

      iex> Dx.Util.Map.subtract(%{a: 1, b: 2}, %{a: 1, b: 2})
      %{}

      iex> Dx.Util.Map.subtract(%{a: 1, b: 2}, %{a: 1, b: 2, d: 4})
      %{}
  """
  def subtract(map, map) do
    %{}
  end

  def subtract(map1, map2) do
    Map.reject(map1, fn {k, _v} -> Map.has_key?(map2, k) end)
  end

  @doc """
  When given two maps, merges the second map into the first.
  When the first argument is `nil`, returns the second argument.
  """
  def maybe_merge(nil, other), do: other
  def maybe_merge(map, other), do: Map.merge(map, other)
end
