defmodule Dx.Ecto.Scope do
  import Ecto.Query

  def resolve_and_build(queryable, scope) do
    state = %{
      aliases: MapSet.new(),
      parent_aliases: MapSet.new(),
      current_alias: nil,
      current_alias_type: :unknown,
      in_subquery?: false,
      post_load: {:loaded}
    }

    case resolve(scope.plan, state) do
      {{:ok, plan}, res_state} ->
        dbg(plan)
        # build(plan, state)

        {query, state} = build(plan, state)

        {:ok, query, res_state.post_load}

      {other, _state} ->
        other
    end
  end

  def to_query(queryable, %{scope: scope}) do
    state = %{
      aliases: MapSet.new(),
      parent_aliases: MapSet.new(),
      current_alias: nil,
      current_alias_type: :unknown,
      in_subquery?: false,
      post_load: {:loaded}
    }

    case resolve(scope.plan, state) do
      {{:ok, plan}, res_state} ->
        dbg(plan)
        # build(plan, state)

        {query, state} = build(plan, state)
        dbg(state)
        # dbg(query, structs: false)
        dbg(query)
        {query, res_state.post_load}

      {:error, state} ->
        {queryable, state}
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
    next_index = Enum.count(state.aliases)
    new_alias = String.to_atom("a#{next_index}")

    state = %{
      state
      | current_alias: new_alias,
        current_alias_type: module,
        aliases: MapSet.put(state.aliases, new_alias)
    }

    {:ok, {:queryable, module}}
    |> with_state(state)
  end

  defp resolve({:field, base, field}, state) do
    # resolve(base, state)
    # |> if_ok(&{:field, &1, field})
    resolve(base, state)
    |> if_ok(fn base, state ->
      case state.current_alias_type.__schema__(:association, field) do
        nil ->
          {:ok, {:field, base, field}}
          |> with_state(state)

        %{cardinality: :many, queryable: module} ->
          state = %{state | parent_aliases: MapSet.union(state.parent_aliases, state.aliases)}
          next_index = Enum.count(state.aliases)
          new_alias = String.to_atom("a#{next_index}")

          state = %{
            state
            | current_alias: new_alias,
              current_alias_type: module,
              aliases: MapSet.put(state.aliases, new_alias),
              in_subquery?: true
          }

          {:ok, {:field, base, field}}
          |> with_state(state)
      end
    end)
  end

  defp resolve({:count, base}, state) do
    resolve(base, state)
    |> if_ok(&{:count, &1})
  end

  defp resolve({:filter, base, condition}, state) do
    resolve(base, state)
    |> if_ok(fn base, state ->
      resolve_condition(condition, state)
      |> if_ok(&{:filter, base, &1})
    end)
  end

  # defp resolve_condition({:error, %Dx.Defd.Fn{fun: fun}}, state)
  #      when is_function(fun, 1) do
  #   resolve_condition({:error, fun}, state)
  # end

  defp resolve_condition({:error, fun}, state) when is_function(fun, 2) do
    state = %{state | post_load: {:filter, state.post_load, fun}}
    {:skip, state}
  end

  defp resolve_condition(fun, state) when is_function(fun, 1) do
    IO.inspect(fun, label: :calling)

    case fun.({:ref, state.current_alias}) |> dbg() do
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
    |> dbg()
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

  defp build_value(term, state) do
    case build(term, state) do
      {%Ecto.Query{} = query, state} -> dynamic(subquery(query)) |> with_state(state)
      other -> other
    end
  end

  # defp build({:ok, %Dx.Scope{} = scope}, state) do
  #   build(scope, state)
  # end

  # defp build(%Dx.Scope{} = scope, state) do
  #   {query, new_state} = build(scope.plan, state)

  #   query =
  #     if new_state.in_subquery? |> dbg() do
  #       dynamic(subquery(query))
  #     else
  #       query
  #     end

  #   {query, %{new_state | in_subquery?: state.in_subquery?}}
  # end

  defp build({:value, value}, state) do
    dynamic(^value)
    |> with_state(state)
  end

  defp build({:ref, ref}, state) do
    dynamic([{^ref, x}], x)
    |> with_state(state)
  end

  defp build({:queryable, module}, state) do
    next_index = Enum.count(state.aliases)
    {query, new_alias} = aliased_from(module, next_index)

    state = %{
      state
      | current_alias: new_alias,
        current_alias_type: module,
        aliases: MapSet.put(state.aliases, new_alias)
    }

    query
    |> with_state(state)
  end

  defp build({:field, base, field}, state) do
    {base, state} = build(base, state)
    current_alias = state.current_alias

    case state.current_alias_type.__schema__(:association, field) do
      nil ->
        dynamic([{^current_alias, x}], field(x, ^field))
        |> with_state(state)

      %{cardinality: :one, queryable: module} ->
        next_index = Enum.count(state.aliases)
        {query, new_alias} = aliased_join(base, current_alias, field, next_index)

        state = %{
          state
          | current_alias: new_alias,
            current_alias_type: module,
            aliases: MapSet.put(state.aliases, new_alias)
        }

        query
        |> with_state(state)

      %{cardinality: :many, queryable: module, related_key: related_key, owner_key: owner_key} ->
        state = %{state | parent_aliases: MapSet.union(state.parent_aliases, state.aliases)}
        next_index = Enum.count(state.aliases)
        {query, new_alias} = aliased_from(module, next_index)

        query =
          where(
            query,
            field(as(^new_alias), ^related_key) == field(parent_as(^current_alias), ^owner_key)
          )

        state = %{
          state
          | current_alias: new_alias,
            current_alias_type: module,
            aliases: MapSet.put(state.aliases, new_alias),
            in_subquery?: true
        }

        query
        |> with_state(state)
    end
  end

  defp build({:count, base}, state) do
    {base, state} = build(base, state)

    select(base, count())
    |> with_state(state)
  end

  defp build({:filter, base, condition}, state) do
    {base, state} = build(base, state)
    {condition, state} = build_condition(condition, state)

    where(base, ^condition)
    |> with_state(state)
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

  def run_post_load(results, {:filter, {:loaded}, fun}, eval) do
    Dx.Defd.Result.filter(results, fun, eval)
    # Dx.Enum.filter(enumerable, %Dx.Defd.Fn{fun: filter})
  end

  def run_post_load(results, post_load, eval) do
    {:ok, results}
  end

  # def to_query(queryable, %{scope: scope}) do
  #   state = %{
  #     aliases: MapSet.new()
  #   }

  #   {query, _state} =
  #     {queryable, state}
  #     |> add_root_alias()
  #     |> apply_conditions(scope)
  #     |> apply_cardinality(scope)

  #   query
  # end

  # def apply_cardinality({queryable, state}, %{cardinality: :all}) do
  #   {queryable, state}
  # end

  # def apply_cardinality({queryable, state}, %{cardinality: :count}) do
  #   select(queryable, count())
  #   |> with_state(state)
  # end

  # def apply_conditions({queryable, state}, %{query_conditions: true}) do
  #   {queryable, state}
  # end

  # def apply_conditions({queryable, state}, scope) do
  #   {fragment, state} = to_fragment(scope.query_conditions, state)
  #   {where(queryable, ^fragment), state}
  # end

  # defp add_root_alias({queryable, state}) do
  #   queryable = from(root in queryable, as: :root)
  #   state = Map.update!(state, :aliases, &MapSet.put(&1, :root))

  #   {queryable, state}
  # end

  # def to_fragment({:value, value}, state) do
  #   dynamic(^value)
  #   |> with_state(state)
  # end

  # def to_fragment({:ref, ref}, state) do
  #   dynamic([{^ref, reff}], reff)
  #   |> with_state(state)
  # end

  # def to_fragment({:field, {:ref, ref}, field}, state) when is_atom(field) do
  #   dynamic([{^ref, x}], field(x, ^field))
  #   |> with_state(state)
  # end

  # # def to_fragment({:field, base, field}, state) do
  # #   {base_fragment, state} = to_fragment(base, state)
  # #   {field_fragment, state} = to_fragment(field, state)

  # #   dynamic(field(^base_fragment, ^field_fragment))
  # #   |> with_state(state)
  # # end

  # def to_fragment({:eq, nil, ref}, state), do: to_fragment({:eq, ref, nil}, state)

  # def to_fragment({:eq, ref, nil}, state) do
  #   {fragment, state} = to_fragment(ref, state)

  #   dynamic(is_nil(^fragment))
  #   |> with_state(state)
  # end

  # def to_fragment({:eq, left, right}, state) do
  #   {left_fragment, state} = to_fragment(left, state)
  #   {right_fragment, state} = to_fragment(right, state)

  #   dynamic(^left_fragment == ^right_fragment)
  #   |> with_state(state)
  # end

  # def to_fragment({:all_of, conditions}, state) do
  #   {condition_fragments, state} =
  #     conditions
  #     |> Enum.map_reduce(state, &to_fragment/2)

  #   Enum.reduce(condition_fragments, &dynamic(^&2 and ^&1))
  #   |> with_state(state)
  # end

  defp with_state(term, state), do: {term, state}

  defp if_ok({:skip, state}, _fun), do: {:skip, state}
  defp if_ok({{:ok, result}, state}, fun) when is_function(fun, 2), do: fun.(result, state)
  defp if_ok({{:ok, result}, state}, fun), do: {{:ok, fun.(result)}, state}
  defp if_ok({:error, state}, _fun), do: {:error, state}

  # defp if_ok_then({{:ok, result}, state}, fun), do: fun.(result, state)
  # defp if_ok_then({:error, state}, _fun), do: {:error, state}

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

  defp chase_down_queryable([field], schema) do
    case schema.__schema__(:association, field) do
      %{queryable: queryable} ->
        queryable

      %Ecto.Association.HasThrough{through: through} ->
        chase_down_queryable(through, schema)

      val ->
        raise """
        Valid association #{field} not found on schema #{inspect(schema)}
        Got: #{inspect(val)}
        """
    end
  end

  defp chase_down_queryable([field | fields], schema) do
    case schema.__schema__(:association, field) do
      %{queryable: queryable} ->
        chase_down_queryable(fields, queryable)

      %Ecto.Association.HasThrough{through: [through_field | through_fields]} ->
        [through_field | through_fields ++ fields]
        |> chase_down_queryable(schema)
    end
  end
end
