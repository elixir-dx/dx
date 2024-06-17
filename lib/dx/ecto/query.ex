defmodule Dx.Ecto.Query do
  # Functions to dynamically generate Ecto query parts.

  @moduledoc false

  alias Dx.{Result, Util}
  alias Dx.Evaluation, as: Eval
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

  defmodule TranslationError do
    defexception [:queryable, :condition]

    def message(e),
      do: "Could not translate some conditions to SQL:\n#{inspect(e.condition, pretty: true)}"
  end

  @doc """
  Add predicate-based filters to a queryable and return it.
  """
  def where(queryable, condition, opts \\ []) when is_list(opts) do
    eval = Eval.from_options(opts)

    case apply_condition(queryable, condition, eval) do
      {queryable, true} -> queryable
      {queryable, condition} -> raise TranslationError, queryable: queryable, condition: condition
    end
  end

  @doc """
  Returns a 2-tuple with

    1. the modified queryable with the given conditions applied as WHERE clauses
    2. any remaining conditions that couldn't be added to the query

  Returns `{query, true}` if all conditions could be added to the query.
  """
  def apply_condition(queryable, condition, %Eval{} = eval) do
    queryable
    |> Builder.init(eval)
    |> apply_condition(condition)
    |> case do
      {:not_loaded, data_reqs} ->
        eval = Eval.load_data_reqs(eval, data_reqs)
        apply_condition(queryable, condition, eval)

      {builder, condition} ->
        {builder.root_query, condition}
    end
  end

  # maps a condition and adds it to the current `root_query`
  defp apply_condition(builder, condition) when is_map(condition) do
    apply_condition(builder, {:all, condition})
  end

  defp apply_condition(builder, {:all, conditions}) do
    conditions
    |> Result.map(&Result.wrap(map_condition(builder, &1)))
    |> case do
      {:not_loaded, data_reqs} ->
        {:not_loaded, data_reqs}

      {:ok, _conditions, _binds} ->
        Enum.reduce(conditions, {builder, []}, fn condition, {builder, remaining_conditions} ->
          case map_condition(builder, condition) do
            {builder, where} ->
              query = builder.root_query
              query = from(q in query, where: ^where)
              builder = %{builder | root_query: query}
              {builder, remaining_conditions}

            :error ->
              {builder, [condition | remaining_conditions]}
          end
        end)
        |> case do
          {builder, []} -> {builder, true}
          {builder, conditions} -> {builder, {:all, conditions}}
        end
    end
  end

  defp apply_condition(builder, condition) do
    case map_condition(builder, condition) do
      {:not_loaded, data_reqs} ->
        {:not_loaded, data_reqs}

      {builder, where} ->
        query = builder.root_query
        query = from(q in query, where: ^where)
        builder = %{builder | root_query: query}
        {builder, true}

      :error ->
        {builder, condition}
    end
  end

  # maps a Dx condition to an Ecto query condition
  defp map_condition(builder, bool) when is_boolean(bool) do
    {builder, bool}
  end

  defp map_condition(builder, {:not, condition}) do
    case map_condition(builder, condition) do
      :error -> :error
      {:not_loaded, data_reqs} -> {:not_loaded, data_reqs}
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
        {:not_loaded, data_reqs} -> {:halt, {:not_loaded, data_reqs}}
        {builder, where} -> {:cont, {builder, combine_and(where, acc_query)}}
      end
    end)
  end

  defp map_condition(builder, conditions) when is_list(conditions) do
    Enum.reduce_while(conditions, {builder, false}, fn condition, {builder, acc_query} ->
      case map_condition(builder, condition) do
        :error -> {:halt, :error}
        {:not_loaded, data_reqs} -> {:halt, {:not_loaded, data_reqs}}
        {builder, where} -> {:cont, {builder, combine_or(where, acc_query)}}
      end
    end)
  end

  defp map_condition(builder, {:args, sub_condition}) do
    case Dx.Engine.evaluate_condition(
           {:args, sub_condition},
           builder.eval.root_subject,
           builder.eval
         ) do
      {:ok, result, _} -> {builder, result}
      {:not_loaded, data_reqs} -> {:not_loaded, data_reqs}
    end
  end

  defp map_condition(_builder, {fun, _args}) when is_function(fun) do
    :error
  end

  defp map_condition(builder, {key, val}) when is_atom(key) do
    case field_info(key, builder) do
      :field ->
        left = Builder.field(builder, key)

        case val do
          vals when is_list(vals) ->
            groups =
              vals
              |> List.flatten()
              |> Enum.group_by(fn
                val when is_integer(val) -> :integer
                val when is_float(val) -> :float
                val when is_binary(val) or is_atom(val) -> :string
                _other -> :other
              end)

            {other_vals, simple_groups} = Map.pop(groups, :other, [])
            grouped_vals = Map.values(simple_groups) ++ other_vals

            Enum.reduce_while(grouped_vals, {builder, false}, fn val, {builder, acc_query} ->
              case val do
                vals when is_list(vals) -> {builder, compare(left, :eq, vals, builder)}
                val -> map_condition(builder, {key, val})
              end
              |> case do
                :error -> {:halt, :error}
                {:not_loaded, data_reqs} -> {:halt, {:not_loaded, data_reqs}}
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

  # maps the right side of a Dx condition to an Ecto Query value
  defp to_val(builder, {:ref, path}), do: reference_path(builder, path)
  defp to_val(builder, val) when is_simple(val), do: {builder, val}

  # returns a reference to a field as an Ecto Query value
  defp reference_path(builder, path) do
    Builder.from_root(builder, fn builder ->
      do_ref(builder, path)
    end)
  end

  defp do_ref(builder, [:args | _] = path) do
    case Dx.Engine.resolve_source({:ref, path}, builder.eval) do
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

  # maps a comparison of "predicate equals value" to a Dx condition
  defp rules_for_value(rules, val, %{negate?: false}) do
    vals = List.wrap(val)

    rules
    |> Enum.reverse()
    |> Enum.reduce_while(false, fn
      {condition, val}, acc when is_simple(val) ->
        if val in vals do
          {:cont, [condition, acc]}
        else
          {:cont, {:all, [{:not, condition}, acc]}}
        end

      _other, _acc ->
        {:halt, :error}
    end)
    |> simplify_condition()
  end

  defp simplify_condition(conditions) when is_map(conditions) do
    simplify_condition({:all, Enum.to_list(conditions)})
  end

  defp simplify_condition({:all, []}), do: true

  defp simplify_condition({:all, conditions}) when is_list(conditions) do
    conditions
    # flatten
    |> Enum.reduce([], fn
      {:all, []}, acc ->
        acc

      {:all, other}, acc when is_list(other) ->
        case simplify_condition({:all, other}) do
          {:all, other} -> acc ++ other
          other -> acc ++ [other]
        end

      other, acc ->
        acc ++ [other]
    end)
    # shorten
    |> Enum.reverse()
    |> Enum.reduce_while([], fn condition, acc ->
      case simplify_condition(condition) do
        false -> {:halt, false}
        true -> {:cont, acc}
        condition -> {:cont, [condition | acc]}
      end
    end)
    # wrap / unwrap
    |> case do
      [condition] -> condition
      conditions when is_list(conditions) -> {:all, conditions}
      other -> other
    end
  end

  defp simplify_condition([]), do: false

  defp simplify_condition(conditions) when is_list(conditions) do
    conditions
    # flatten
    |> Enum.flat_map(fn
      [] -> [false]
      list when is_list(list) -> simplify_condition(list) |> wrap_condition()
      other -> [other]
    end)
    # shorten
    |> Enum.reverse()
    |> Enum.reduce_while([], fn condition, acc ->
      case simplify_condition(condition) do
        true -> {:halt, true}
        false -> {:cont, acc}
        other -> {:cont, [other, acc]}
      end
    end)
    # unwrap
    |> case do
      [condition] -> condition
      other -> other
    end
  end

  defp simplify_condition(condition), do: condition

  defp wrap_condition(list) when is_list(list), do: list
  defp wrap_condition(other), do: [other]

  @doc """
  Applies all known options to the given `queryable`
  and returns it, along with all options that were unknown.
  """
  def apply_options(queryable, opts) do
    Enum.reduce(opts, {queryable, []}, fn
      {:where, conditions}, {query, opts} -> {where(query, conditions), opts}
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

  def inspect(query, repo) do
    IO.puts(to_sql(repo, query))
    query
  end

  @doc "Returns generated SQL for given query with all params replaced"
  def to_sql(repo, query) do
    {sql, params} = repo.to_sql(:all, query)

    replace_params(sql, params)
  end

  def replace_params(sql, params) when is_binary(sql) and is_list(params) do
    params
    |> Enum.with_index(1)
    |> Enum.reverse()
    |> Enum.reduce(sql, fn {param, i}, sql ->
      String.replace(sql, "$#{i}", sql_escape(param))
    end)
  end

  defp sql_escape(term, dquote \\ false)

  defp sql_escape(true, _), do: "TRUE"
  defp sql_escape(false, _), do: "FALSE"
  defp sql_escape(nil, _), do: "NULL"
  defp sql_escape(number, _) when is_integer(number) or is_float(number), do: to_string(number)

  defp sql_escape(list, _) when is_list(list),
    do: "'{#{Enum.map_join(list, ", ", &sql_escape(&1, true))}}'"

  defp sql_escape(str, true) when is_binary(str), do: "\"#{String.replace(str, "\"", "\\\"")}\""
  defp sql_escape(str, false) when is_binary(str), do: "'#{String.replace(str, "'", "\'")}'"
  defp sql_escape(other, dquote), do: other |> to_string() |> sql_escape(dquote)
end
