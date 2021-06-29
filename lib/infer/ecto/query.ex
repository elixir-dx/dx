defmodule Infer.Ecto.Query do
  @moduledoc """
  Functions to dynamically generate Ecto query parts.
  """

  alias Infer.Util

  import Ecto.Query, only: [from: 2, dynamic: 2]

  defguard is_simple(val)
           when is_integer(val) or is_float(val) or is_atom(val) or is_binary(val) or
                  is_boolean(val) or is_nil(val) or is_struct(val)

  @lt_ops ~w(< lt less_than before)a
  @lte_ops ~w(<= lte less_than_or_equal on_or_before at_or_before)a
  @gte_ops ~w(>= gte greater_than_or_equal on_or_after at_or_after)a
  @gt_ops ~w(> gt greater_than after)a
  @all_ops @lt_ops ++ @lte_ops ++ @gte_ops ++ @gt_ops

  def apply_condition(queryable, {:not, condition}, eval) do
    eval = Map.update!(eval, :negate?, &Kernel.not/1)

    apply_condition(queryable, condition, eval)
  end

  def apply_condition(queryable, conditions, eval) when is_map(conditions) do
    apply_condition(queryable, {:all, conditions}, eval)
  end

  def apply_condition(queryable, {:all, conditions}, eval) do
    {conditions, queryable} =
      Enum.flat_map_reduce(conditions, queryable, fn condition, queryable ->
        case apply_condition(queryable, condition, eval) do
          {queryable, true} -> {[], queryable}
          {queryable, condition} -> {[condition], queryable}
        end
      end)

    {queryable, {:all, conditions} |> maybe_negate(eval)}
  end

  def apply_condition(queryable, {key, {op, val}}, eval)
      when is_atom(key) and op in @all_ops and is_simple(val) do
    type = get_type(queryable)

    case Util.rules_for_predicate(key, type, eval) do
      [] -> {do_apply(queryable, key, op, val, eval), true}
      _rules -> {queryable, {key, val}}
    end
  end

  def apply_condition(queryable, {key, val}, eval) when is_atom(key) and is_simple(val) do
    type = get_type(queryable)

    case Util.rules_for_predicate(key, type, eval) do
      [] ->
        {do_apply(queryable, key, :eq, val, eval), true}

      rules ->
        case rules_for_value(rules, val, eval) do
          :error -> {queryable, {key, val}}
          condition -> apply_condition(queryable, condition, eval)
        end
    end
  end

  def apply_condition(queryable, condition, _eval) do
    {queryable, condition}
  end

  defp maybe_negate({:all, []}, _eval), do: true
  defp maybe_negate({:all, [condition]}, %{negate?: false}), do: condition
  defp maybe_negate({:all, conditions}, %{negate?: false}), do: {:all, conditions}
  defp maybe_negate({:all, [condition]}, %{negate?: true}), do: {:not, condition}
  defp maybe_negate({:all, conditions}, %{negate?: true}), do: {:not, {:all, conditions}}

  defp do_apply(queryable, key, :eq, nil, %{negate?: false}),
    do: from(q in queryable, where: is_nil(field(q, ^key)))

  defp do_apply(queryable, key, :eq, nil, %{negate?: true}),
    do: from(q in queryable, where: not is_nil(field(q, ^key)))

  defp do_apply(queryable, key, :eq, val, %{negate?: false}),
    do: from(q in queryable, where: field(q, ^key) == ^val)

  defp do_apply(queryable, key, :eq, val, %{negate?: true}),
    do: from(q in queryable, where: field(q, ^key) != ^val)

  defp do_apply(queryable, key, op, val, %{negate?: false}) when op in @lt_ops,
    do: from(q in queryable, where: field(q, ^key) < ^val)

  defp do_apply(queryable, key, op, val, %{negate?: true}) when op in @lt_ops,
    do: from(q in queryable, where: field(q, ^key) >= ^val)

  defp do_apply(queryable, key, op, val, %{negate?: false}) when op in @lte_ops,
    do: from(q in queryable, where: field(q, ^key) <= ^val)

  defp do_apply(queryable, key, op, val, %{negate?: true}) when op in @lte_ops,
    do: from(q in queryable, where: field(q, ^key) > ^val)

  defp do_apply(queryable, key, op, val, %{negate?: false}) when op in @gte_ops,
    do: from(q in queryable, where: field(q, ^key) >= ^val)

  defp do_apply(queryable, key, op, val, %{negate?: true}) when op in @gte_ops,
    do: from(q in queryable, where: field(q, ^key) < ^val)

  defp do_apply(queryable, key, op, val, %{negate?: false}) when op in @gt_ops,
    do: from(q in queryable, where: field(q, ^key) > ^val)

  defp do_apply(queryable, key, op, val, %{negate?: true}) when op in @gt_ops,
    do: from(q in queryable, where: field(q, ^key) <= ^val)

  defp get_type(%Ecto.Query{from: %{source: {_, type}}}), do: type

  defp rules_for_value(rules, val, %{negate?: false}) do
    Enum.reduce_while(rules, {:pre, []}, fn
      {condition, ^val}, {:pre, nots} when condition == %{} -> {:cont, {:ok, [], nots}}
      {condition, ^val}, {:pre, nots} -> {:cont, {:ok, [condition], nots}}
      {condition, ^val}, {:ok, conditions, nots} -> {:cont, {:ok, [condition | conditions], nots}}
      {_condition, ^val}, {:done, _conditions, _nots} -> {:halt, :error}
      {_condition, complex}, _ when not is_simple(complex) -> {:halt, :error}
      {condition, _other}, {:pre, nots} -> {:cont, {:pre, [{:not, condition} | nots]}}
      {_condition, _other}, {:ok, conditions, nots} -> {:cont, {:done, conditions, nots}}
      {_condition, _other}, {:done, _conditions, _nots} = acc -> {:cont, acc}
    end)
    |> case do
      {_, [], nots} -> {:all, nots}
      {_, [condition], nots} -> {:all, [condition | nots]}
      {_, conditions, nots} -> {:all, [conditions | nots]}
      {:pre, nots} -> {:all, nots}
      :error -> :error
    end
    |> case do
      {:all, []} -> %{}
      {:all, [condition]} -> condition
      {:all, conditions} -> {:all, Enum.reverse(conditions)}
      :error -> :error
    end
  end

  @doc """
  Applies all known options to the given `queryable`
  and returns it, along with all options that were unknown.
  """
  def apply_options(queryable, opts) do
    Enum.reduce(opts, {queryable, []}, fn
      {:where, conditions}, {query, opts} -> {filter_by(query, conditions), opts}
      {:limit, limit}, {query, opts} -> {limit(query, limit), opts}
      {:order_by, order}, {query, opts} -> {order_by(query, order), opts}
      other, {query, opts} -> {query, [other | opts]}
    end)
    |> case do
      {queryable, opts} -> {queryable, Enum.reverse(opts)}
    end
  end

  @doc "Apply all options to the given `queryable`, raise on any unknown option."
  def from_options(queryable, opts) do
    {queryable, []} = apply_options(queryable, opts)
    queryable
  end

  def filter_by(queryable, conditions) do
    Enum.reduce(conditions, queryable, fn
      {key, nil}, queryable ->
        from(q in queryable, where: is_nil(field(q, ^key)))

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
