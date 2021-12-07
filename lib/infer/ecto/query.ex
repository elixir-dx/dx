defmodule Infer.Ecto.Query do
  @moduledoc """
  Functions to dynamically generate Ecto query parts.
  """

  alias Infer.Util
  alias Infer.Evaluation, as: Eval
  alias __MODULE__.Builder

  import Ecto.Query, only: [dynamic: 1, dynamic: 2, from: 2]

  defguard is_simple(val)
           when is_integer(val) or is_float(val) or is_atom(val) or is_binary(val) or
                  is_boolean(val) or is_nil(val) or is_struct(val)

  @lt_ops ~w(< lt less_than before)a
  @lte_ops ~w(<= lte less_than_or_equal on_or_before at_or_before)a
  @gte_ops ~w(>= gte greater_than_or_equal on_or_after at_or_after)a
  @gt_ops ~w(> gt greater_than after)a
  @all_ops @lt_ops ++ @lte_ops ++ @gte_ops ++ @gt_ops

  @doc """
  Add predicate-based filters to a queryable and return it.
  """
  def where(queryable, condition, opts \\ []) when is_list(opts) do
    eval = Eval.from_options(opts)
    {queryable, true} = apply_condition(queryable, condition, eval)
    queryable
  end

  @doc """
  Returns a 2-tuple with

    1. the modified queryable with the given conditions applied as WHERE clauses
    2. any remaining conditions that couldn't be added to the query

  Returns `{query, true}` if all conditions could be added to the query.
  """
  def apply_condition(queryable, condition, %Eval{} = eval) do
    {builder, condition} =
      queryable
      |> Builder.init(eval)
      |> apply_condition(condition)

    {builder.root_query, condition}
  end

  # maps a condition and adds it to the current `root_query`
  defp apply_condition(builder, condition) do
    case map_condition(builder, condition) do
      {builder, where} ->
        query = builder.root_query
        query = from(q in query, where: ^where)
        builder = %{builder | root_query: query}
        {builder, true}

      :error ->
        {builder, condition}
    end
  end

  # maps a Infer condition to an Ecto query condition
  defp map_condition(builder, {:not, condition}) do
    case map_condition(builder, condition) do
      :error -> :error
      {builder, where} -> {builder, dynamic(not (^where))}
    end
  end

  defp map_condition(builder, conditions) when is_map(conditions) do
    map_condition(builder, {:all, conditions})
  end

  defp map_condition(builder, {:all, conditions}) do
    Enum.reduce_while(conditions, {builder, true}, fn condition, {builder, acc_query} ->
      case map_condition(builder, condition) do
        :error -> {:halt, :error}
        {builder, where} -> {:cont, {builder, combine_and(where, acc_query)}}
      end
    end)
  end

  defp map_condition(builder, conditions) when is_list(conditions) do
    Enum.reduce_while(conditions, {builder, false}, fn condition, {builder, acc_query} ->
      case map_condition(builder, condition) do
        :error -> {:halt, :error}
        {builder, where} -> {:cont, {builder, combine_or(where, acc_query)}}
      end
    end)
  end

  defp map_condition(builder, {:args, sub_condition}) do
    case Infer.Engine.evaluate_condition(
           {:args, sub_condition},
           builder.eval.root_subject,
           builder.eval
         ) do
      {:ok, result, _} -> {builder, result}
    end
  end

  defp map_condition(builder, {key, val}) when is_atom(key) do
    case field_info(key, builder) do
      :field ->
        left = Builder.field(builder, key)

        case val do
          vals when is_list(vals) ->
            Enum.reduce_while(vals, {builder, false}, fn val, {builder, acc_query} ->
              case map_condition(builder, {key, val}) do
                :error -> {:halt, :error}
                {builder, where} -> {:cont, {builder, combine_or(where, acc_query)}}
              end
            end)

          {:not, val} ->
            Builder.negate(builder, fn builder ->
              with {builder, right} <- to_val(builder, val) do
                {builder, compare(left, :eq, right, builder)}
              end
            end)

          {op, val} when op in @all_ops ->
            with {builder, right} <- to_val(builder, val) do
              {builder, compare(left, op, right, builder)}
            end

          val ->
            with {builder, right} <- to_val(builder, val) do
              {builder, compare(left, :eq, right, builder)}
            end
        end

      {:predicate, rules} ->
        case rules_for_value(rules, val, builder) do
          :error -> :error
          condition -> map_condition(builder, condition)
        end

      {:assoc, :one, _assoc} ->
        Builder.with_join(builder, key, fn builder ->
          map_condition(builder, val)
        end)

      {:assoc, :many, assoc} ->
        %{queryable: queryable, related_key: related_key, owner_key: owner_key} = assoc

        as = Builder.current_alias(builder)

        subquery =
          from(q in queryable,
            where: field(q, ^related_key) == field(parent_as(^as), ^owner_key)
          )

        Builder.step_into(builder, key, subquery, fn builder ->
          map_condition(builder, val)
        end)
    end
  end

  # maps the right side of a Infer condition to an Ecto Query value
  defp to_val(builder, {:ref, path}), do: reference_path(builder, path)
  defp to_val(builder, val) when is_simple(val), do: {builder, val}

  # returns a reference to a field as an Ecto Query value
  defp reference_path(builder, path) do
    Builder.from_root(builder, fn builder ->
      do_ref(builder, path)
    end)
  end

  defp do_ref(builder, [:args | _] = path) do
    case Infer.Engine.resolve_source({:ref, path}, builder.eval) do
      {:ok, result, _} -> {builder, result}
    end
  end

  defp do_ref(builder, field) when is_atom(field), do: do_ref(builder, [field])

  defp do_ref(builder, [field]) do
    {builder, Builder.field(builder, field, true)}
  end

  defp do_ref(builder, [field | path]) do
    case field_info(field, builder) do
      {:assoc, :one, _assoc} -> Builder.with_join(builder, field, &do_ref(&1, path))
      _other -> :error
    end
  end

  defp combine_and(true, right), do: right
  defp combine_and(left, true), do: left
  defp combine_and(false, _right), do: false
  defp combine_and(_left, false), do: false
  defp combine_and(left, right), do: dynamic(^left and ^right)

  defp combine_or(true, _right), do: true
  defp combine_or(_left, true), do: true
  defp combine_or(false, right), do: right
  defp combine_or(left, false), do: left
  defp combine_or(left, right), do: dynamic(^left or ^right)

  defp compare(left, :eq, nil, %{negate?: false}),
    do: dynamic(is_nil(^left))

  defp compare(left, :eq, nil, %{negate?: true}),
    do: dynamic(not is_nil(^left))

  defp compare(left, :eq, vals, %{negate?: false}) when is_list(vals),
    do: dynamic(^left in ^vals)

  defp compare(left, :eq, vals, %{negate?: true}) when is_list(vals),
    do: dynamic(^left not in ^vals)

  defp compare(left, :eq, val, %{negate?: false}),
    do: dynamic(^left == ^val)

  defp compare(left, :eq, val, %{negate?: true}),
    do: dynamic(^left != ^val)

  defp compare(left, op, val, %{negate?: false}) when op in @lt_ops,
    do: dynamic(^left < ^val)

  defp compare(left, op, val, %{negate?: true}) when op in @lt_ops,
    do: dynamic(^left >= ^val)

  defp compare(left, op, val, %{negate?: false}) when op in @lte_ops,
    do: dynamic(^left <= ^val)

  defp compare(left, op, val, %{negate?: true}) when op in @lte_ops,
    do: dynamic(^left > ^val)

  defp compare(left, op, val, %{negate?: false}) when op in @gte_ops,
    do: dynamic(^left >= ^val)

  defp compare(left, op, val, %{negate?: true}) when op in @gte_ops,
    do: dynamic(^left < ^val)

  defp compare(left, op, val, %{negate?: false}) when op in @gt_ops,
    do: dynamic(^left > ^val)

  defp compare(left, op, val, %{negate?: true}) when op in @gt_ops,
    do: dynamic(^left <= ^val)

  defp field_info(predicate, %Builder{} = builder) do
    type = Builder.current_type(builder)

    case Util.rules_for_predicate(predicate, type, builder.eval) do
      [] ->
        case Util.Ecto.association_details(type, predicate) do
          %_{cardinality: :one} = assoc ->
            {:assoc, :one, assoc}

          %_{cardinality: :many} = assoc ->
            {:assoc, :many, assoc}

          _other ->
            case Util.Ecto.field_details(type, predicate) do
              nil ->
                raise ArgumentError,
                      """
                      Unknown field #{inspect(predicate)} on #{inspect(type)}.
                      Path:  #{inspect(builder.path)}
                      Types: #{inspect(builder.types)}
                      """

              _other ->
                :field
            end
        end

      rules ->
        {:predicate, rules}
    end
  end

  # maps a comparison of "predicate equals value" to an Infer condition
  # in the form of "all preceding rules yielding other values must NOT match
  # AND any rule yielding the value must match".
  # The rules matching the value must be in a row.
  # In any other case, or in the case of non-simple rule results, `:error` is returned.
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
      {:where, conditions}, {query, opts} when is_list(conditions) ->
        {where(query, {:all, conditions}), opts}

      {:where, conditions}, {_query, _opts} ->
        raise ArgumentError,
              "Expected a list of conditions in Infer query operator. Got " <>
                inspect(conditions, pretty: true)

      {:limit, limit}, {query, opts} ->
        {limit(query, limit), opts}

      {:order_by, order}, {query, opts} ->
        {order_by(query, order), opts}

      other, {query, opts} ->
        {query, [other | opts]}
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

  @doc "Returns generated SQL for given query with all params replaced"
  def to_sql(repo, query) do
    {sql, params} = repo.to_sql(:all, query)

    params
    |> Enum.with_index(1)
    |> Enum.reverse()
    |> Enum.reduce(sql, fn {param, i}, sql ->
      String.replace(sql, "$#{i}", sql_escape(param))
    end)
  end

  defp sql_escape(true), do: "TRUE"
  defp sql_escape(false), do: "FALSE"
  defp sql_escape(nil), do: "NULL"
  defp sql_escape(number) when is_integer(number) or is_float(number), do: to_string(number)

  defp sql_escape(list) when is_list(list),
    do: "(#{Enum.map(list, &sql_escape/1) |> Enum.join(", ")})"

  defp sql_escape(str) when is_binary(str), do: "'#{String.replace(str, "'", "\'")}'"
  defp sql_escape(other), do: other |> to_string() |> sql_escape()
end
