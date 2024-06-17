defmodule Dx.Util.Enum do
  # Utility functions for working with `Enum` data structures.

  @moduledoc false

  def zip(enum1, enum2, fun, reverse_result \\ [])

  def zip([elem1 | enum1], [elem2 | enum2], fun, reverse_result) do
    reverse_result = [fun.(elem1, elem2) | reverse_result]
    zip(enum1, enum2, fun, reverse_result)
  end

  def zip([], [], _fun, reverse_result) do
    Enum.reverse(reverse_result)
  end
end
