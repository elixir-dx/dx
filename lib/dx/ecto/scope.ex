defmodule Dx.Ecto.Scope do
  import Ecto.Query

  defmodule Query do
    defstruct [
      :query,
      :ref,
      cardinality: :many,
      aggregate_default: nil
    ]
  end

  @state %{
    queries: [],
    cardinality: :many,
    aggregate_default: nil,
    alias_types: Map.new(),
    post_load: {:loaded}
  }

  def to_query(_queryable, %{scope: scope}) do
    %{queries: [query]} =
      state =
      case build(scope.plan, @state) do
        {_ref, state} -> state
        state -> state
      end

    scope = %{
      scope
      | cardinality: query.cardinality,
        aggregate_default: query.aggregate_default,
        post_load: state.post_load
    }

    {query.query, scope}
  end

  # RESOLVE
  # -------
  def resolve(%Dx.Scope{} = scope) do
    case resolve(scope.plan, %{}) do
      {plan, _ref, _state} ->
        scope = %{scope | plan: plan}

        {:ok, scope}

      {other, _state} ->
        other
    end
  end

  defp resolve(%Dx.Scope{} = scope, refs) do
    resolve(scope.plan, refs)
  end

  defp resolve({:error, defd_fallback}, refs) do
    {{:error, defd_fallback}, nil, refs}
  end

  defp resolve({:ref, ref}, refs) do
    {{:ref, ref}, ref, refs}
  end

  defp resolve({:queryable, queryable}, refs) do
    {ref, refs} = new_ref(queryable, refs)

    {{:as, ref, queryable, {:queryable, queryable}}, ref, refs}
  end

  defp resolve({:field_or_assoc, map, field}, refs) when is_map(map) do
    case Map.fetch!(map, field) do
      %Ecto.Association.NotLoaded{} -> :error
      other -> resolve(other, refs)
    end
  end

  defp resolve({:field_or_assoc, base, field}, refs) do
    case resolve(base, refs) do
      {base, nil, refs} ->
        resolve({:field_or_assoc, base, field}, refs)

      {base, ref, refs} ->
        type = refs[ref]

        case type.__schema__(:association, field) do
          nil ->
            {{:field, base, field}, ref, refs}

          %{cardinality: :one, queryable: module} ->
            {ref, refs} = new_ref(module, refs)

            {{:as, ref, module, {:assoc, :one, base, field}}, ref, refs}

          %{cardinality: :many, queryable: module} = assoc ->
            {ref, refs} = new_ref(module, refs)

            {{:as, ref, module, {:assoc, :many, assoc.owner_key, assoc.related_key, base, field}},
             ref, refs}
        end

      :error ->
        :error
    end
  end

  defp resolve({:count, base}, refs) do
    {base, _ref, refs} = resolve(base, refs)
    {{:count, base}, nil, refs}
  end

  defp resolve({:filter, base, condition}, refs) do
    {base, ref, refs} = resolve(base, refs)
    {condition, _ref, refs} = resolve_condition(condition, ref, refs)
    {{:filter, base, condition}, ref, refs}
  end

  defp resolve(value, refs) do
    {value, nil, refs}
  end

  defp new_ref(new_ref_type, refs) do
    next_index = map_size(refs)
    ref = :"a#{next_index}"
    refs = Map.put(refs, ref, new_ref_type)

    {ref, refs}
  end

  defp resolve_condition(fun, ref, refs) when is_function(fun, 1) do
    case fun.({:ref, ref}) do
      {:error, defd_fun} -> {{:error, defd_fun}, ref, refs}
      condition -> resolve_condition(condition, ref, refs)
    end
  end

  defp resolve_condition({:all_of, conditions}, ref, refs) do
    {conditions, refs} =
      Enum.map_reduce(conditions, refs, fn condition, refs ->
        {condition, _ref, refs} = resolve_condition(condition, ref, refs)
        {condition, refs}
      end)

    {{:all_of, conditions}, ref, refs}
  end

  defp resolve_condition({:eq, {:error, _fallback}, _right, fallback}, ref, refs) do
    {{:error, fallback}, ref, refs}
  end

  defp resolve_condition({:eq, :error, _right, fallback}, ref, refs) do
    {{:error, fallback}, ref, refs}
  end

  defp resolve_condition({:eq, _left, {:error, _fallback}, fallback}, ref, refs) do
    {{:error, fallback}, ref, refs}
  end

  defp resolve_condition({:eq, _left, :error, fallback}, ref, refs) do
    {{:error, fallback}, ref, refs}
  end

  defp resolve_condition({:eq, left, right, fallback}, ref, refs) do
    with {left, _ref, refs} <- resolve(left, refs),
         {right, _ref, refs} <- resolve(right, refs) do
      {{:eq, left, right}, ref, refs}
    else
      :error -> {{:error, fallback}, ref, refs}
    end
  end

  # BUILD
  # -----
  defp build({:as, ref, type, {:queryable, queryable}}, state) do
    query = from(x in queryable, as: ^ref)

    state = %{
      state
      | queries: [%Query{ref: ref, query: query} | state.queries],
        alias_types: Map.put(state.alias_types, ref, type)
    }

    {:ref, ref}
    |> with_state(state)
  end

  defp build({:as, new_ref, type, {:assoc, :one, {:ref, ref}, field}}, state) do
    state =
      map_query(state, &join(&1, :inner, [{^ref, x}], y in assoc(x, ^field), as: ^new_ref))
      |> Map.put(:alias_types, Map.put(state.alias_types, new_ref, type))

    {:ref, new_ref}
    |> with_state(state)
  end

  defp build({:as, new_ref, type, {:assoc, :one, base, field}}, state) do
    {{:ref, ref}, state} = build(base, state)

    state =
      map_query(state, &join(&1, :inner, [{^ref, x}], y in assoc(x, ^field), as: ^new_ref))
      |> Map.put(:alias_types, Map.put(state.alias_types, new_ref, type))

    {:ref, new_ref}
    |> with_state(state)
  end

  defp build(
         {:as, new_ref, type, {:assoc, :many, owner_key, related_key, {:ref, ref}, _field}},
         state
       ) do
    query =
      from(x in type,
        as: ^new_ref,
        where: field(x, ^related_key) == field(parent_as(^ref), ^owner_key)
      )

    state = %{
      state
      | queries: [%Query{ref: new_ref, query: query} | state.queries],
        alias_types: Map.put(state.alias_types, new_ref, type)
    }

    {:ref, new_ref}
    |> with_state(state)
  end

  defp build({:field, {:ref, ref}, field}, state) do
    dynamic([{^ref, x}], field(x, ^field))
    |> with_state(state)
  end

  defp build({:field, base, field}, state) do
    {{:ref, ref}, state} = build(base, state)

    dynamic([{^ref, x}], field(x, ^field))
    |> with_state(state)
  end

  defp build({:count, base}, state) do
    {_ref, state} = build(base, state)

    map_query(state, &select(&1, %{result: count()}), cardinality: :one, aggregate_default: 0)
  end

  defp build({:filter, base, condition}, state) do
    {ref, state} = build(base, state)
    {condition, state} = build_condition(condition, ref, state)

    state = map_query(state, &where(&1, ^condition))

    {ref, state}
  end

  defp build(value, state) do
    dynamic(^value)
    |> with_state(state)
  end

  defp build_condition(fun, base, state) when is_function(fun, 1) do
    base |> fun.() |> build_condition(base, state)
  end

  defp build_condition({:error, defd_fun}, _base, state) do
    %{queries: [%{ref: base_ref} | _queries]} = state

    state = Map.update!(state, :post_load, &{:filter, defd_fun, {:ref, base_ref}, &1})

    {true, state}
  end

  defp build_condition({:all_of, conditions}, base, state) do
    {conditions, state} = Enum.map_reduce(conditions, state, &build_condition(&1, base, &2))
    conditions = Enum.reduce(conditions, &dynamic(^&2 and ^&1))

    {conditions, state}
  end

  defp build_condition({:eq, left, right}, _base, state) do
    {left, state} = build_value(left, state)
    {right, state} = build_value(right, state)

    dynamic(^left == ^right)
    |> with_state(state)
  end

  defp build_value(term, state) do
    case build(term, state) do
      %{queries: [%Query{query: query, cardinality: :one} | queries]} = state ->
        dynamic(subquery(query)) |> with_state(%{state | queries: queries})

      other ->
        other
    end
  end

  defp map_query(%{queries: [query | queries]} = state, fun) do
    %{state | queries: [Map.update!(query, :query, fun) | queries]}
  end

  defp map_query(%{queries: [query | queries]} = state, fun, attributes) do
    %{
      state
      | queries: [Map.merge(Map.update!(query, :query, fun), Map.new(attributes)) | queries]
    }
  end

  def run_post_load(results, {:filter, fun, {:ref, :a0}, {:loaded}}, eval) do
    results
    |> Dx.Defd.Result.then(&Dx.Defd.Result.filter(&1, fun, eval))
  end

  def run_post_load(results, {:filter, fun, {:ref, :a0}, rest}, eval) do
    results
    |> run_post_load(rest, eval)
    |> Dx.Defd.Result.then(&Dx.Defd.Result.filter(&1, fun, eval))
  end

  def run_post_load(results, {:loaded}, _eval) do
    results
  end

  ## Helpers

  @compile {:inline, with_state: 2}
  defp with_state(term, state), do: {term, state}
end
