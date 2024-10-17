defmodule Dx.Util.List do
  # Utility functions for working with `List` data structures.

  @moduledoc false

  def intersect?([], _other), do: false
  def intersect?([elem | rest], other), do: elem in other or intersect?(rest, other)
end
