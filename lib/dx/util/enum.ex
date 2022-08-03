defmodule Dx.Util.Enum do
  @moduledoc """
  Utility functions for working with `Enum` data structures.
  """

  def zip(enum1, enum2, fun, reverse_result \\ [])

  def zip([elem1 | enum1], [elem2 | enum2], fun, reverse_result) do
    reverse_result = [fun.(elem1, elem2) | reverse_result]
    zip(enum1, enum2, fun, reverse_result)
  end

  def zip([], [], _fun, reverse_result) do
    Enum.reverse(reverse_result)
  end

  @doc """
  Finds an element in `enum` for which `updater` does not return `:error`.
  If an element is found, replaces it with the `updater` result in the `enum`.
  If no element is found, appends `append` at the end of `enum`.

  ## Examples

      iex> try_update_or_append([1, 2, 3, 4, 5], &if(&1 > 2, do: &1 + 3, else: :error), 0)
      [1, 2, 6, 4, 5]

      iex> try_update_or_append([1, 2, 3, 4], fn _ -> :error end, 0)
      [1, 2, 3, 4, 0]
  """
  def try_update_or_append(enum, updater, append) do
    do_try_update_or_append(enum, updater, append, [])
  end

  defp do_try_update_or_append([], _updater, append, acc) do
    Enum.reverse(acc, [append])
  end

  defp do_try_update_or_append([elem | rest], updater, append, acc) do
    case updater.(elem) do
      :error -> do_try_update_or_append(rest, updater, append, [elem | acc])
      elem -> Enum.reverse(acc, [elem | rest])
    end
  end
end
