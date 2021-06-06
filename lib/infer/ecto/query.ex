defmodule Infer.Ecto.Query do
  @moduledoc """
  Functions to dynamically generate Ecto query parts.
  """

  import Ecto.Query, only: [from: 2, dynamic: 2]

  def filter_by(queryable, conditions) do
    Enum.reduce(conditions, queryable, fn
      {key, list}, queryable when is_list(list) ->
        from(q in queryable, where: field(q, ^key) in ^list)

      {key, val}, queryable ->
        from(q in queryable, where: field(q, ^key) == ^val)
    end)
  end

  def limit(queryable, limit) do
    from(q in queryable, limit: ^limit)
  end

  def order_by(queryable, field) when is_atom(field) do
    from(q in queryable, order_by: field(q, ^field))
  end

  # see https://hexdocs.pm/ecto/Ecto.Query.html#dynamic/2-order_by
  def order_by(queryable, fields) when is_list(fields) do
    fields =
      fields
      |> Enum.map(fn
        {direction, field} -> {direction, dynamic([q], field(q, ^field))}
        field -> dynamic([q], field(q, ^field))
      end)

    from(q in queryable, order_by: ^fields)
  end
end
