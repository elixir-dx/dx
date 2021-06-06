defmodule Infer.Ecto.Query do
  @moduledoc """
  Functions to dynamically generate Ecto query parts.
  """

  import Ecto.Query, only: [from: 2]

  def filter_by(queryable, conditions) do
    Enum.reduce(conditions, queryable, fn {key, val}, queryable ->
      from(q in queryable, where: field(q, ^key) == ^val)
    end)
  end
end
