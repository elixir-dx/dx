defmodule Dx.Util.Enum do
  # Utility functions for working with `Enum` data structures.

  @moduledoc false

  @doc """
  Maps only elements at given indexes using given fun.

  ## Examples

      iex> map_indexes([1, 2, 3], [0, 2, 4], & &1 + 1)
      [2, 2, 4]
  """
  def map_indexes(enum, indexes, fun) do
    Enum.with_index(enum, fn elem, index ->
      if index in indexes, do: fun.(elem), else: elem
    end)
  end

  def zip(enum1, enum2, fun, reverse_result \\ [])

  def zip([elem1 | enum1], [elem2 | enum2], fun, reverse_result) do
    reverse_result = [fun.(elem1, elem2) | reverse_result]
    zip(enum1, enum2, fun, reverse_result)
  end

  def zip([], [], _fun, reverse_result) do
    Enum.reverse(reverse_result)
  end
end
