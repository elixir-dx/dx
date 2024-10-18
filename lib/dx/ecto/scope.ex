defmodule Dx.Ecto.Scope do
  @moduledoc false

  import Ecto.Query

  defmodule Query do
    @moduledoc false

    defstruct [
      :query,
      :ref,
      cardinality: :many,
      aggregate?: false,
      aggregate_default: nil
    ]
  end

  @state %{
    queries: [],
    cardinality: :many,
    aggregate?: false,
    aggregate_default: nil,
    alias_types: Map.new(),
    post_load: {:loaded}
  }

  defguard in_subquery?(state) when length(state.queries) > 1

  def to_query(_queryable, %{scope: scope}) do
    state = %{@state | post_load: scope.post_load}

    %{queries: [query]} =
      state =
      case build(scope.plan, state) do
        {_ref, state} -> state
        state -> state
      end

    scope = %{
      scope
      | cardinality: query.cardinality,
        aggregate?: query.aggregate?,
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
        scope = %{scope | plan: normalize(plan)}

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
            field_type = type.__schema__(:type, field)
            {{:field, field_type, base, field}, ref, refs}

          %{cardinality: :one, queryable: module} = assoc ->
            {ref, refs} = new_ref(module, refs)
            owner_key_type = assoc.owner.__schema__(:type, assoc.owner_key)
            related_key_type = assoc.related.__schema__(:type, assoc.related_key)

            {{:as, ref, module,
              {:assoc, :one, owner_key_type, assoc.owner_key, related_key_type, assoc.related_key,
               base, field}}, ref, refs}

          %{cardinality: :many, queryable: module} = assoc ->
            {ref, refs} = new_ref(module, refs)
            owner_key_type = assoc.owner.__schema__(:type, assoc.owner_key)
            related_key_type = assoc.related.__schema__(:type, assoc.related_key)

            {{:as, ref, module,
              {:assoc, :many, owner_key_type, assoc.owner_key, related_key_type,
               assoc.related_key, base, field}}, ref, refs}
        end

      :error ->
        :error
    end
  end

  defp resolve({:count, base}, refs) do
    {base, _ref, refs} = resolve(base, refs)
    {{:count, base}, nil, refs}
  end

  defp resolve({:first, base}, refs) do
    {base, _ref, refs} = resolve(base, refs)
    {{:first, base}, nil, refs}
  end

  defp resolve({:any?, base, fallback}, refs) do
    {base, _ref, refs} = resolve(base, refs)
    {{:any?, base, fallback}, nil, refs}
  end

  defp resolve({:filter, base, condition}, refs) do
    {base, ref, refs} = resolve(base, refs)
    {condition, _ref, refs} = resolve_condition(condition, ref, refs)
    {{:filter, base, condition}, ref, refs}
  end

  defp resolve({:compare, left, right, fallback}, refs) do
    with {left, _ref, refs} <- resolve(left, refs),
         {right, _ref, refs} <- resolve(right, refs) do
      {{:compare, left, right}, nil, refs}
    else
      :error -> {{:error, fallback}, nil, refs}
    end
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

  defp resolve_condition({:any_of, conditions, fallback}, ref, refs) do
    {conditions, refs} =
      Enum.map_reduce(conditions, refs, fn condition, refs ->
        {condition, _ref, refs} = resolve_condition(condition, ref, refs)
        {condition, refs}
      end)

    {{:any_of, conditions, fallback}, ref, refs}
  end

  defp resolve_condition({:error, fallback}, ref, refs) do
    {{:error, fallback}, ref, refs}
  end

  defp resolve_condition({:not, condition}, ref, refs) do
    {condition, _ref, refs} = resolve_condition(condition, ref, refs)
    {{:not, condition}, ref, refs}
  end

  defp resolve_condition({:and, left, right, _fallback}, ref, refs) do
    resolve_condition({:all_of, [left, right]}, ref, refs)
  end

  defp resolve_condition({:&&, condition, then, fallback}, ref, refs) do
    resolve_condition({:and, condition, then, fallback}, ref, refs)
  end

  defp resolve_condition({:or, left, right, fallback}, ref, refs) do
    resolve_condition({:any_of, [left, right], fallback}, ref, refs)
  end

  defp resolve_condition({:||, condition, then, fallback}, ref, refs) do
    resolve_condition({:or, condition, then, fallback}, ref, refs)
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

  @ops [:lt, :eq, :gt]
  defp resolve_condition({op, left, right, fallback}, ref, refs)
       when op in @ops do
    with {left, _ref, refs} <- resolve(left, refs),
         {right, _ref, refs} <- resolve(right, refs) do
      {{op, left, right}, ref, refs}
    else
      :error -> {{:error, fallback}, ref, refs}
    end
  end

  defp resolve_condition(other, _ref, refs) do
    resolve(other, refs)
  end

  # NORMALIZE
  # ---------

  defp normalize({:filter, {:filter, base, condition}, other_condition}) do
    normalize({:filter, base, {:all_of, [condition, other_condition]}})
  end

  defp normalize({:filter, base, condition}) do
    {:filter, normalize(base), normalize_condition(condition)}
  end

  defp normalize(other), do: other

  defp flatten_condition(op, conditions) do
    Enum.flat_map(conditions, fn
      {^op, conditions} -> flatten_condition(op, conditions)
      condition -> [normalize_condition(condition)]
    end)
  end

  defp normalize_condition({:all_of, conditions}) do
    {:all_of, flatten_condition(:all_of, conditions)}
  end

  defp normalize_condition({:any_of, conditions, fallback}) do
    {:any_of, flatten_condition(:any_of, conditions), fallback}
  end

  defp normalize_condition({unary, base}) when unary in [:count, :first] do
    {unary, normalize(base)}
  end

  defp normalize_condition({:any?, base, fallback}) do
    {:any?, normalize(base), fallback}
  end

  defp normalize_condition({:not, condition}) do
    {:not, normalize_condition(condition)}
  end

  defp normalize_condition({:eq, nil, right}) do
    {:eq, right, nil}
    |> normalize_condition()
  end

  # Ecto.Enum
  defp normalize_condition(
         {:eq, left,
          {:field, {:parameterized, Ecto.Enum, %{type: type, mappings: mappings}}, base, field}}
       ) do
    {:eq, {:field, {:parameterized, Ecto.Enum, %{type: type, mappings: mappings}}, base, field},
     left}
    |> normalize_condition()
  end

  # Ecto.Enum in newer Ecto versions
  defp normalize_condition(
         {:eq, left,
          {:field, {:parameterized, {Ecto.Enum, %{type: type, mappings: mappings}}}, base, field}}
       ) do
    {:eq, {:field, {:parameterized, Ecto.Enum, %{type: type, mappings: mappings}}, base, field},
     left}
    |> normalize_condition()
  end

  defp normalize_condition(
         {:eq,
          {:field, {:parameterized, {Ecto.Enum, %{type: type, mappings: mappings}}}, base, field},
          right}
       ) do
    {:eq, {:field, {:parameterized, Ecto.Enum, %{type: type, mappings: mappings}}, base, field},
     right}
    |> normalize_condition()
  end

  defp normalize_condition(
         {:eq,
          {:field, {:parameterized, Ecto.Enum, %{type: type, mappings: mappings}}, base, field},
          right}
       ) do
    value =
      Keyword.get(mappings, right) ||
        raise ArgumentError,
              "#{inspect(right)} is not a valid value for field #{field}. Valid values are: " <>
                Enum.map_join(mappings, ", ", &inspect(elem(&1, 0)))

    {:eq, {:field, type, base, field}, value}
    |> normalize_condition()
  end

  # assoc == %struct{}
  defp normalize_condition(
         {op,
          {:as, _, type,
           {:assoc, :one, foreign_key_type, foreign_key_field, _related_key_type,
            related_key_field, base, _field}}, %type{} = struct}
       )
       when op in @ops do
    {op, {:field, foreign_key_type, normalize(base), foreign_key_field},
     Map.fetch!(struct, related_key_field)}
    |> normalize_condition()
  end

  # compare/2 functions
  defp normalize_condition({:eq, {:compare, left, right}, op})
       when op in [:lt, :gt, :eq] do
    {op, left, right}
    |> normalize_condition()
  end

  # boolean field as condition
  defp normalize_condition({:field, :boolean, base, field}) do
    {:eq, {:field, :boolean, normalize(base), field}, true}
    |> normalize_condition()
  end

  # non-boolean field as condition
  defp normalize_condition({:field, type, base, field}) do
    {:not, {:eq, {:field, type, normalize(base), field}, nil}}
    |> normalize_condition()
  end

  # assoc as condition
  defp normalize_condition(
         {:as, ref, type,
          {:assoc, :one, foreign_key_type, foreign_key_field, related_key_type, related_key_field,
           base, field}}
       ) do
    {:not,
     {:eq,
      {:as, ref, type,
       {:assoc, :one, foreign_key_type, foreign_key_field, related_key_type, related_key_field,
        normalize(base), field}}, nil}}
    |> normalize_condition()
  end

  # assoc == nil
  defp normalize_condition(
         {:eq,
          {:as, _, _, {:assoc, :one, foreign_key_type, foreign_key_field, _, _, base, _field}},
          nil}
       ) do
    {:eq, {:field, foreign_key_type, normalize(base), foreign_key_field}, nil}
    |> normalize_condition()
  end

  defp normalize_condition(other), do: other

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

  defp build({:as, new_ref, type, {:assoc, :one, _, _, _, _, {:ref, ref}, field}}, state) do
    state =
      map_query(state, &join(&1, :inner, [{^ref, x}], y in assoc(x, ^field), as: ^new_ref))
      |> Map.put(:alias_types, Map.put(state.alias_types, new_ref, type))

    {:ref, new_ref}
    |> with_state(state)
  end

  defp build({:as, new_ref, type, {:assoc, :one, _, _, _, _, base, field}}, state) do
    case build(base, state) do
      {{:ref, ref}, state} ->
        state =
          map_query(state, &join(&1, :inner, [{^ref, x}], y in assoc(x, ^field), as: ^new_ref))
          |> Map.put(:alias_types, Map.put(state.alias_types, new_ref, type))

        {:ref, new_ref}
        |> with_state(state)

      :error ->
        :error
    end
  end

  defp build(
         {:as, new_ref, type, {:assoc, :many, _, owner_key, _, related_key, {:ref, ref}, _field}},
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

  defp build({:field, _type, {:ref, ref}, field}, %{queries: [%{ref: ref} | _]} = state) do
    dynamic(field(as(^ref), ^field))
    |> with_state(state)
  end

  defp build({:field, _type, {:ref, ref}, field}, state) do
    dynamic(field(parent_as(^ref), ^field))
    |> with_state(state)
  end

  defp build({:field, _type, base, field}, state) do
    case build(base, state) do
      {{:ref, ref}, state} ->
        dynamic([{^ref, x}], field(x, ^field))
        |> with_state(state)

      :error ->
        :error
    end
  end

  defp build({:count, base}, state) do
    {_ref, state} = build(base, state)

    map_query(state, &select(&1, %{result: count()}),
      cardinality: :one,
      aggregate?: true,
      aggregate_default: 0
    )
  end

  defp build({:first, base}, state) do
    {_ref, state} = build(base, state)

    map_query(state, &limit(&1, 1), cardinality: :one)
  end

  defp build({:filter, base, condition}, state) do
    case build(base, state) do
      {ref, state} ->
        case build_condition(condition, state) do
          {condition, fallback, state} ->
            state = state |> build_query_filter(condition) |> build_fallback_filter(fallback)

            {ref, state}

          :error ->
            :error
        end

      :error ->
        :error
    end
  end

  defp build(value, state) do
    dynamic(^value)
    |> with_state(state)
  end

  defp build_query_filter(state, :skip), do: state
  defp build_query_filter(state, condition), do: map_query(state, &where(&1, ^condition))

  defp build_fallback_filter(state, :skip), do: state

  defp build_fallback_filter(state, fallback) do
    Map.update!(state, :post_load, &{:filter, fallback, {:ref, current_ref(state)}, &1})
  end

  # build_condition/2 can return either
  #   {query, fallback, state}
  #     query :: Ecto dynamic | :skip
  #     fallback :: fun | :skip | {:all_of, funs} | {:any_of, funs}
  #   :error (no fallback possible)
  #
  defp build_condition({:error, defd_fun}, state) do
    {:skip, defd_fun, state}
  end

  defp build_condition({:all_of, conditions}, state) do
    Enum.reduce_while(conditions, {[], [], state}, fn condition, {conditions, fallbacks, state} ->
      case build_condition(condition, state) do
        {condition, :skip, state} ->
          {:cont, {maybe_prepend(condition, conditions), fallbacks, state}}

        {_condition, _fallback, state} when in_subquery?(state) ->
          {:halt, :error}

        {condition, fallback, state} ->
          {:cont,
           {maybe_prepend(condition, conditions), maybe_prepend(fallback, fallbacks), state}}

        :error when in_subquery?(state) ->
          {:halt, :error}

        :error ->
          raise ArgumentError,
                "Condition must provide fallback function: \n\n" <>
                  inspect(condition, pretty: true)
      end
    end)
    |> case do
      {conditions, fallbacks, state} ->
        conditions =
          case conditions do
            [] -> :skip
            conditions -> conditions |> :lists.reverse() |> Enum.reduce(&dynamic(^&2 and ^&1))
          end

        fallbacks =
          case fallbacks do
            [] -> :skip
            [fallback] -> fallback
            fallbacks -> {:all_of, fallbacks}
          end

        {conditions, fallbacks, state}

      :error ->
        :error
    end
  end

  defp build_condition({:any_of, conditions, fallback}, state) do
    Enum.reduce_while(conditions, {[], [], state}, fn condition, {conditions, fallbacks, state} ->
      case build_condition(condition, state) do
        {:skip, _, _} ->
          {:halt, :skip}

        {condition, fallback, state} ->
          {:cont,
           {maybe_prepend(condition, conditions), maybe_prepend(fallback, fallbacks), state}}

        :error ->
          {:halt, :error}
      end
    end)
    |> case do
      {conditions, fallbacks, state} ->
        conditions =
          case conditions do
            [] -> :skip
            conditions -> conditions |> :lists.reverse() |> Enum.reduce(&dynamic(^&2 or ^&1))
          end

        fallbacks =
          case fallbacks do
            [] -> :skip
            _other -> fallback
          end

        {conditions, fallbacks, state}

      :skip ->
        {:skip, fallback, state}

      :error ->
        :error
    end
  end

  defp build_condition({:any?, base, fallback}, state) do
    case build(base, state) do
      {_ref, %{queries: [%{query: subquery} | queries]} = state} ->
        state = %{state | queries: queries}
        subquery = select(subquery, true)

        dynamic(exists(subquery(subquery)))
        |> with_fallback_and_state(state)

      :error when in_subquery?(state) ->
        :error

      :error ->
        {:skip, fallback, state}
    end
  end

  defp build_condition({:not, condition}, state) do
    case build_condition(condition, state) do
      {condition, :skip, state} ->
        dynamic(not (^condition))
        |> with_fallback_and_state(state)

      {:skip, fallback, state} ->
        {:skip, {:not, fallback}, state}

      {condition, fallback, state} ->
        dynamic(not (^condition))
        |> with_fallback_and_state({:not, fallback}, state)

      :error ->
        :error
    end
  end

  defp build_condition({:eq, left, nil}, state) do
    case build_value(left, state) do
      {left, state} ->
        dynamic(is_nil(^left))
        |> with_fallback_and_state(state)

      :error ->
        :error
    end
  end

  defp build_condition({:eq, left, right}, state) do
    case build_value(left, state) do
      {left, state} ->
        case build_value(right, state) do
          {right, state} ->
            dynamic(^left == ^right)
            |> with_fallback_and_state(state)

          :error ->
            :error
        end

      :error ->
        :error
    end
  end

  defp build_condition({:lt, left, right}, state) do
    case build_value(left, state) do
      {left, state} ->
        case build_value(right, state) do
          {right, state} ->
            dynamic(^left < ^right)
            |> with_fallback_and_state(state)

          :error ->
            :error
        end

      :error ->
        :error
    end
  end

  defp build_condition({:gt, left, right}, state) do
    case build_value(left, state) do
      {left, state} ->
        case build_value(right, state) do
          {right, state} ->
            dynamic(^left > ^right)
            |> with_fallback_and_state(state)

          :error ->
            :error
        end

      :error ->
        :error
    end
  end

  defp build_condition(bool, state) when is_boolean(bool) do
    bool
    |> with_fallback_and_state(state)
  end

  defp maybe_prepend(:skip, acc), do: acc
  defp maybe_prepend(elem, acc), do: [elem | acc]

  defp build_value(term, state) do
    case build(term, state) do
      %{queries: [%Query{query: query, cardinality: :one} | queries]} = state ->
        dynamic(subquery(query)) |> with_state(%{state | queries: queries})

      other ->
        other
    end
  end

  def run_post_load(results, {:filter, {:not, fun}, {:ref, :a0}, rest}, eval) do
    results
    |> run_post_load(rest, eval)
    |> Dx.Defd.Result.then(&Dx.Defd.Result.reject(&1, fun, eval))
  end

  def run_post_load(results, {:filter, fun, {:ref, :a0}, rest}, eval) do
    results
    |> run_post_load(rest, eval)
    |> Dx.Defd.Result.then(&Dx.Defd.Result.filter(&1, fun, eval))
  end

  def run_post_load(results, {:filter, ext_ok_fun, rest}, eval) do
    results
    |> run_post_load(rest, eval)
    |> Dx.Defd.Result.transform(fn results ->
      Enum.filter(results, fn result ->
        {:ok, result} = ext_ok_fun.(result)
        result
      end)
    end)
  end

  def run_post_load(results, {:loaded}, _eval) do
    results
  end

  ## Helpers

  @compile {:inline,
            with_state: 2,
            with_fallback_and_state: 2,
            with_fallback_and_state: 3,
            current_ref: 1,
            map_query: 2,
            map_query: 3}
  defp with_state(term, state), do: {term, state}
  defp with_fallback_and_state(term, fallback \\ :skip, state), do: {term, fallback, state}

  defp current_ref(%{queries: [%{ref: ref} | _queries]}), do: ref

  defp map_query(%{queries: [query | queries]} = state, fun) do
    %{state | queries: [Map.update!(query, :query, fun) | queries]}
  end

  defp map_query(%{queries: [query | queries]} = state, fun, attributes) do
    %{
      state
      | queries: [Map.merge(Map.update!(query, :query, fun), Map.new(attributes)) | queries]
    }
  end
end
