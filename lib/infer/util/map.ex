defmodule Infer.Util.Map do
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
end
