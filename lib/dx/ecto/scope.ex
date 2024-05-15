defmodule Dx.Ecto.Scope do
  import Ecto.Query

  @state %{
    queries: [],
    cardinality: :many,
    aggregate_default: nil,
    alias_types: Map.new(),
    current_alias: nil,
    post_load: {:loaded}
  }

  def to_query(_queryable, %{scope: scope}) do
    %{queries: [query]} = build(scope.plan, @state)

    {query, scope}
  end

  def resolve(%Dx.Scope{} = scope) do
    case resolve(scope.plan, @state) do
      {{:ok, plan}, state} ->
        scope = %{
          scope
          | plan: plan,
            cardinality: state.cardinality,
            aggregate_default: state.aggregate_default,
            post_load: state.post_load
        }

        {:ok, scope}

      {other, _state} ->
        other
    end
  end

  defp resolve(fun, state) when is_function(fun, 1) do
    resolve(fun.({:ref, state.current_alias}), state)
  end

  # TODO: Make this redundant & remove it
  defp resolve({:ok, wrapped}, state) do
    resolve(wrapped, state)
  end

  defp resolve(%Dx.Scope{} = scope, state) do
    resolve(scope.plan, state)
  end

  defp resolve({:value, value}, state) do
    {:ok, {:value, value}}
    |> with_state(state)
  end

  defp resolve({:ref, ref}, state) do
    {:ok, {:ref, ref}}
    |> with_state(state)
  end

  defp resolve({:queryable, module}, state) do
    next_index = Enum.count(state.alias_types)
    new_alias = String.to_atom("a#{next_index}")

    state = %{
      state
      | cardinality: :many,
        current_alias: new_alias,
        alias_types: Map.put(state.alias_types, new_alias, module)
    }

    {:ok, {:queryable, module}}
    |> with_state(state)
  end

  defp resolve({:field_or_assoc, base, field}, state) do
    resolve(base, state)
    |> if_ok(fn base, state ->
      current_alias_type = state.alias_types[state.current_alias]

      case current_alias_type.__schema__(:association, field) do
        nil ->
          {:ok, {:field, base, field}}
          |> with_state(state)

        %{cardinality: :one, queryable: module} ->
          next_index = Enum.count(state.alias_types)
          new_alias = String.to_atom("a#{next_index}")

          state = %{
            state
            | current_alias: new_alias,
              alias_types: Map.put(state.alias_types, new_alias, module)
          }

          {:ok, {:assoc, base, field}}
          |> with_state(state)

        %{cardinality: :many, queryable: module} ->
          next_index = Enum.count(state.alias_types)
          new_alias = String.to_atom("a#{next_index}")

          state = %{
            state
            | current_alias: new_alias,
              alias_types: Map.put(state.alias_types, new_alias, module)
          }

          {:ok, {:assoc, base, field}}
          |> with_state(state)
      end
    end)
  end

  defp resolve({:count, base}, state) do
    resolve(base, state)
    |> put_state(:cardinality, :one)
    |> put_state(:aggregate_default, 0)
    |> if_ok(&{:count, &1})
  end

  defp resolve({:filter, base, condition}, state) do
    cardinality = state.cardinality
    aggregate_default = state.aggregate_default

    resolve(base, state)
    |> put_state(:cardinality, cardinality)
    |> put_state(:aggregate_default, aggregate_default)
    |> if_ok(fn base, state ->
      resolve_condition(condition, state)
      |> put_state(:cardinality, cardinality)
      |> put_state(:aggregate_default, aggregate_default)
      |> if_ok(&{:filter, base, &1})
    end)
  end

  defp resolve_condition({:error, fun}, state) when is_function(fun, 2) do
    state = %{state | post_load: {:filter, state.post_load, fun}}
    {:skip, state}
  end

  defp resolve_condition(fun, state) when is_function(fun, 1) do
    case fun.({:ref, state.current_alias}) do
      {:ok, condition} -> resolve_condition(condition, state)
      {:error, condition} -> resolve_condition({:error, condition}, state)
      :error -> {:error, state}
    end
  end

  defp resolve_condition({:all_of, conditions}, state) do
    conditions
    |> Enum.map_reduce(state, &resolve_condition/2)
    |> collect()
    |> if_ok(&{:all_of, &1})
  end

  defp resolve_condition({:eq, left, right}, state) do
    resolve(left, state)
    |> if_ok(fn left, state ->
      resolve(right, state)
      |> if_ok(fn right ->
        {:eq, left, right}
      end)
    end)
  end

  defp build({:value, value}, state) do
    dynamic(^value)
    |> with_state(state)
  end

  defp build({:queryable, module}, state) do
    next_index = Enum.count(state.alias_types)
    {query, new_alias} = aliased_from(module, next_index)

    %{
      state
      | queries: [query | state.queries],
        current_alias: new_alias,
        alias_types: Map.put(state.alias_types, new_alias, module)
    }
  end

  defp build({:field, {:ref, ref}, field}, state) do
    dynamic([{^ref, x}], field(x, ^field))
    |> with_state(state)
  end

  defp build({:assoc, {:ref, ref}, field}, state) do
    type = Map.fetch!(state.alias_types, ref)

    case type.__schema__(:association, field) do
      %{cardinality: :one, queryable: module} ->
        next_index = Enum.count(state.alias_types)
        [query | queries] = state.queries
        {query, new_alias} = aliased_join(query, ref, field, next_index)

        %{
          state
          | queries: [query | queries],
            current_alias: new_alias,
            alias_types: Map.put(state.alias_types, new_alias, module)
        }

      %{cardinality: :many, queryable: module, related_key: related_key, owner_key: owner_key} ->
        next_index = Enum.count(state.alias_types)
        {query, new_alias} = aliased_from(module, next_index)

        query =
          where(
            query,
            field(as(^new_alias), ^related_key) == field(parent_as(^ref), ^owner_key)
          )

        %{
          state
          | queries: [query | state.queries],
            current_alias: new_alias,
            alias_types: Map.put(state.alias_types, new_alias, module)
        }
    end
  end

  defp build({:field, base, field}, state) do
    state = %{} = build(base, state)
    current_alias = state.current_alias
    current_alias_type = state.alias_types[current_alias]

    case current_alias_type.__schema__(:association, field) do
      nil ->
        dynamic([{^current_alias, x}], field(x, ^field))
        |> with_state(state)

      %{cardinality: :one, queryable: module} ->
        next_index = Enum.count(state.alias_types)
        [query | queries] = state.queries
        {query, new_alias} = aliased_join(query, current_alias, field, next_index)

        %{
          state
          | queries: [query | queries],
            current_alias: new_alias,
            alias_types: Map.put(state.alias_types, new_alias, module)
        }

      %{cardinality: :many, queryable: module, related_key: related_key, owner_key: owner_key} ->
        next_index = Enum.count(state.alias_types)
        {query, new_alias} = aliased_from(module, next_index)

        query =
          where(
            query,
            field(as(^new_alias), ^related_key) == field(parent_as(^current_alias), ^owner_key)
          )

        %{
          state
          | queries: [query | state.queries],
            current_alias: new_alias,
            alias_types: Map.put(state.alias_types, new_alias, module)
        }
    end
  end

  defp build({:count, base}, state) do
    state = %{} = build(base, state)
    [query | queries] = state.queries

    query = select(query, %{result: count()})
    %{state | queries: [query | queries], cardinality: :one}
  end

  defp build({:filter, base, condition}, state) do
    state = %{} = build(base, state)
    {condition, state} = build_condition(condition, state)
    [query | queries] = state.queries
    query = where(query, ^condition)

    %{state | queries: [query | queries]}
  end

  defp build_condition(fun, state) when is_function(fun, 1) do
    build_condition(fun.({:ref, state.current_alias}), state)
  end

  defp build_condition({:all_of, conditions}, state) do
    {conditions, state} = Enum.map_reduce(conditions, state, &build_condition/2)
    conditions = Enum.reduce(conditions, &dynamic(^&2 and ^&1))

    {conditions, state}
  end

  defp build_condition({:eq, left, right}, state) do
    {left, state} = build_value(left, state)
    {right, state} = build_value(right, state)

    dynamic(^left == ^right)
    |> with_state(state)
  end

  defp build_value(term, state) do
    case build(term, state) do
      %{queries: [query | queries]} = state ->
        dynamic(subquery(query)) |> with_state(%{state | queries: queries})

      other ->
        other
    end
  end

  def run_post_load(results, {:filter, {:loaded}, fun}, eval) do
    Dx.Defd.Result.filter(results, fun, eval)
  end

  def run_post_load(results, _post_load, _eval) do
    {:ok, results}
  end

  defp with_state(term, state), do: {term, state}
  defp put_state({term, state}, key, value), do: {term, %{state | key => value}}

  defp if_ok({:skip, state}, _fun), do: {:skip, state}
  defp if_ok({{:ok, result}, state}, fun) when is_function(fun, 2), do: fun.(result, state)
  defp if_ok({{:ok, result}, state}, fun), do: {{:ok, fun.(result)}, state}
  defp if_ok({:error, state}, _fun), do: {:error, state}

  defp collect({results, state}) do
    do_collect(results, [])
    |> with_state(state)
  end

  defp do_collect([], acc) do
    {:ok, :lists.reverse(acc)}
  end

  defp do_collect([:skip | rest], acc) do
    do_collect(rest, acc)
  end

  defp do_collect([:error | _rest], _acc) do
    :error
  end

  defp do_collect([{:ok, result} | rest], acc) do
    do_collect(rest, [result | acc])
  end

  defp aliased_from(queryable, 0), do: {from(q in queryable, as: :a0), :a0}
  defp aliased_from(queryable, 1), do: {from(q in queryable, as: :a1), :a1}
  defp aliased_from(queryable, 2), do: {from(q in queryable, as: :a2), :a2}
  defp aliased_from(queryable, 3), do: {from(q in queryable, as: :a3), :a3}
  defp aliased_from(queryable, 4), do: {from(q in queryable, as: :a4), :a4}
  defp aliased_from(queryable, 5), do: {from(q in queryable, as: :a5), :a5}
  defp aliased_from(queryable, 6), do: {from(q in queryable, as: :a6), :a6}
  defp aliased_from(queryable, 7), do: {from(q in queryable, as: :a7), :a7}

  defp aliased_join(queryable, left, key, 0),
    do: {join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a0), :a0}

  defp aliased_join(queryable, left, key, 1),
    do: {join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a1), :a1}

  defp aliased_join(queryable, left, key, 2),
    do: {join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a2), :a2}

  defp aliased_join(queryable, left, key, 3),
    do: {join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a3), :a3}

  defp aliased_join(queryable, left, key, 4),
    do: {join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a4), :a4}

  defp aliased_join(queryable, left, key, 5),
    do: {join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a5), :a5}

  defp aliased_join(queryable, left, key, 6),
    do: {join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a6), :a6}

  defp aliased_join(queryable, left, key, 7),
    do: {join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a7), :a7}
end
