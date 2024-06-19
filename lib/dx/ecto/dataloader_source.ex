defmodule Dx.Ecto.DataloaderSource do
  defstruct [
    :repo,
    :query,
    :run_batch,
    repo_opts: [],
    batches: %{},
    results: %{},
    default_params: %{},
    options: []
  ]

  @type t :: %__MODULE__{
          repo: Ecto.Repo.t(),
          query: query_fun,
          repo_opts: repo_opts,
          batches: map,
          results: map,
          default_params: map,
          run_batch: batch_fun,
          options: Keyword.t()
        }

  @type query_fun :: (Ecto.Queryable.t(), any -> Ecto.Queryable.t())
  @type repo_opts :: Keyword.t()
  @type batch_fun :: (Ecto.Queryable.t(), Ecto.Query.t(), any, [any], repo_opts -> [any])
  @type opt ::
          {:query, query_fun}
          | {:default_params, map()}
          | {:repo_opts, repo_opts}
          | {:timeout, pos_integer}
          | {:run_batch, batch_fun()}

  import Ecto.Query

  @spec new(Ecto.Repo.t(), [opt]) :: t
  def new(repo, opts \\ []) do
    data =
      opts
      |> Keyword.put_new(:query, &query/2)
      |> Keyword.put_new(:run_batch, &run_batch(repo, &1, &2, &3, &4, &5))

    opts = Keyword.take(opts, [:timeout])

    %__MODULE__{repo: repo, options: opts}
    |> struct(data)
  end

  @spec run_batch(
          repo :: Ecto.Repo.t(),
          queryable :: Ecto.Queryable.t(),
          query :: Ecto.Query.t(),
          col :: any,
          inputs :: [any],
          repo_opts :: repo_opts
        ) :: [any]
  def run_batch(repo, queryable, query, col, inputs, repo_opts) do
    results = load_rows(col, inputs, queryable, query, repo, repo_opts)
    grouped_results = group_results(results, col)

    for value <- inputs do
      grouped_results
      |> Map.get(value, [])
      |> Enum.reverse()
    end
  end

  defp load_rows(col, inputs, queryable, query, repo, repo_opts) do
    pk = queryable.__schema__(:primary_key)

    case query do
      %Ecto.Query{limit: limit, offset: offset}
      when pk != [col] and (not is_nil(limit) or not is_nil(offset)) ->
        load_rows_lateral(col, inputs, queryable, query, repo, repo_opts)

      _ ->
        query
        |> build_inputs_where(col, inputs)
        |> repo.all(repo_opts)
    end
  end

  defp load_rows_lateral(col, inputs, queryable, query, repo, repo_opts) do
    # Approximate a postgres unnest with a subquery
    inputs_query =
      queryable
      |> build_inputs_where(col, inputs)
      |> select(^[col])
      |> distinct(true)

    inner_query =
      query
      |> where([q], field(q, ^col) == field(parent_as(:input), ^col))
      |> exclude(:preload)

    results =
      from(input in subquery(inputs_query), as: :input)
      |> join(:inner_lateral, [], q in subquery(inner_query), on: true)
      |> select([_input, q], q)
      |> repo.all(repo_opts)

    case query.preloads do
      [] -> results
      # Preloads can't be used in a subquery, using Repo.preload instead
      preloads -> repo.preload(results, preloads, repo_opts)
    end
  end

  defp build_inputs_where(queryable, field, values) do
    case Enum.split_with(values, &is_nil/1) do
      {[], values} ->
        where(queryable, [q], field(q, ^field) in ^values)

      {_nil, values} ->
        where(queryable, [q], is_nil(field(q, ^field)) or field(q, ^field) in ^values)
    end
  end

  defp group_results(results, col) do
    results
    |> Enum.reduce(%{}, fn result, grouped ->
      value = Map.get(result, col)
      Map.update(grouped, value, [result], &[result | &1])
    end)
  end

  defp query(schema, _) do
    schema
  end

  defimpl Dataloader.Source do
    def run(source) do
      results =
        Dataloader.async_safely(__MODULE__, :run_batches, [source],
          async?: Dataloader.Source.async?(source)
        )

      results =
        Map.merge(source.results, results, fn _, {:ok, v1}, {:ok, v2} ->
          {:ok, Map.merge(v1, v2)}
        end)

      %{source | results: results, batches: %{}}
    end

    def fetch(source, batch_key, item) do
      {batch_key, item_key, _item} =
        batch_key
        |> normalize_key(source.default_params)
        |> get_keys(item)

      with {:ok, batch} <- Map.fetch(source.results, batch_key) do
        fetch_item_from_batch(batch, item_key)
      else
        :error ->
          {:error, "Unable to find batch #{inspect(batch_key)}"}
      end
    end

    defp fetch_item_from_batch(tried_and_failed = {:error, _reason}, _item_key),
      do: tried_and_failed

    defp fetch_item_from_batch({:ok, batch}, item_key) do
      case Map.fetch(batch, item_key) do
        :error -> {:error, "Unable to find item #{inspect(item_key)} in batch"}
        result -> result
      end
    end

    def put(source, _batch, _item, %Ecto.Association.NotLoaded{}) do
      source
    end

    def put(source, batch, item, result) do
      batch = normalize_key(batch, source.default_params)
      {batch_key, item_key, _item} = get_keys(batch, item)

      results =
        Map.update(
          source.results,
          batch_key,
          {:ok, %{item_key => result}},
          fn {:ok, map} -> {:ok, Map.put(map, item_key, result)} end
        )

      %{source | results: results}
    end

    def load(source, batch, item) do
      {batch_key, item_key, item} =
        batch
        |> normalize_key(source.default_params)
        |> get_keys(item)

      if fetched?(source.results, batch_key, item_key) do
        source
      else
        entry = {item_key, item}

        update_in(source.batches, fn batches ->
          Map.update(batches, batch_key, MapSet.new([entry]), &MapSet.put(&1, entry))
        end)
      end
    end

    defp fetched?(results, batch_key, item_key) do
      case results do
        %{^batch_key => {:ok, %{^item_key => _}}} -> true
        _ -> false
      end
    end

    def pending_batches?(%{batches: batches}) do
      batches != %{}
    end

    def timeout(%{options: options}) do
      options[:timeout]
    end

    def async?(%{repo: repo}) do
      not repo.in_transaction?()
    end

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

    defp get_keys({assoc_field, opts}, %schema{} = record) when is_atom(assoc_field) do
      validate_queryable(schema)
      primary_keys = schema.__schema__(:primary_key)
      id = Enum.map(primary_keys, &Map.get(record, &1))

      queryable = chase_down_queryable([assoc_field], schema)

      {{:assoc, schema, self(), assoc_field, queryable, opts}, id, record}
    end

    defp get_keys({{cardinality, queryable}, opts}, value) when is_atom(queryable) do
      validate_queryable(queryable)
      {_, col, value} = normalize_value(queryable, value)
      {{:queryable, self(), queryable, cardinality, col, opts}, value, value}
    end

    defp get_keys({queryable, opts}, value) when is_atom(queryable) do
      validate_queryable(queryable)

      case normalize_value(queryable, value) do
        {:primary, col, value} ->
          {{:queryable, self(), queryable, :one, col, opts}, value, value}

        {:not_primary, col, _value} ->
          raise """
          Cardinality required unless using primary key

          The non-primary key column specified was: #{inspect(col)}
          """
      end
    end

    defp get_keys(key, item) do
      raise """
      Invalid: #{inspect(key)}
      #{inspect(item)}

      The batch key must either be a schema module, or an association name.
      """
    end

    defp validate_queryable(queryable) do
      unless {:__schema__, 1} in queryable.__info__(:functions) do
        raise "The given module - #{queryable} - is not an Ecto schema."
      end
    rescue
      _ in UndefinedFunctionError ->
        raise Dataloader.GetError, """
          The given atom - #{inspect(queryable)} - is not a module.

          This can happen if you intend to pass an Ecto struct in your call to
          `dataloader/4` but pass something other than a struct.
        """
    end

    defp normalize_value(_queryable, []) do
      {:not_primary, nil, nil}
    end

    defp normalize_value(queryable, [{col, value}]) do
      case queryable.__schema__(:primary_key) do
        [^col] ->
          {:primary, col, value}

        _ ->
          {:not_primary, col, value}
      end
    end

    defp normalize_value(queryable, value) do
      [primary_key] = queryable.__schema__(:primary_key)
      {:primary, primary_key, value}
    end

    # This code was totally OK until cardinalities showed up. Now it's ugly :(
    # It is however correct, which is nice.
    @cardinalities [:one, :many]

    defp normalize_key({cardinality, queryable}, default_params)
         when cardinality in @cardinalities do
      normalize_key({{cardinality, queryable}, []}, default_params)
    end

    defp normalize_key({cardinality, queryable, params}, default_params)
         when cardinality in @cardinalities do
      normalize_key({{cardinality, queryable}, params}, default_params)
    end

    defp normalize_key({key, params}, default_params) do
      {key, Enum.into(params, default_params)}
    end

    defp normalize_key(key, default_params) do
      {key, default_params}
    end

    def run_batches(source) do
      options = [
        timeout: source.options[:timeout] || Dataloader.default_timeout(),
        on_timeout: :kill_task
      ]

      batches = Enum.to_list(source.batches)

      results =
        batches
        |> maybe_async_stream(
          fn batch ->
            id = :erlang.unique_integer()
            system_time = System.system_time()
            start_time_mono = System.monotonic_time()

            emit_start_event(id, system_time, batch)
            batch_result = run_batch(batch, source)
            emit_stop_event(id, start_time_mono, batch)

            batch_result
          end,
          options,
          Dataloader.Source.async?(source)
        )
        |> Enum.map(fn
          {:ok, {_key, result}} -> {:ok, result}
          {:exit, reason} -> {:error, reason}
        end)

      batches
      |> Enum.map(fn {key, _set} -> key end)
      |> Enum.zip(results)
      |> Map.new()
    end

    defp maybe_async_stream(batches, fun, options, true) do
      async_stream(batches, fun, options)
    end

    defp maybe_async_stream(batches, fun, _options, _) do
      Enum.map(batches, fn batch ->
        try do
          {:ok, fun.(batch)}
        rescue
          e ->
            {:exit, e}
        end
      end)
    end

    defp run_batch(
           {{:queryable, pid, queryable, cardinality, col, opts} = key, entries},
           source
         ) do
      inputs = Enum.map(entries, &elem(&1, 0))

      query = source.query.(queryable, opts)

      repo_opts = Keyword.put(source.repo_opts, :caller, pid)

      cardinality_mapper = cardinality_mapper(cardinality, queryable)

      coerced_inputs =
        if type = queryable.__schema__(:type, col) do
          for input <- inputs do
            {:ok, input} = Ecto.Type.cast(type, input)
            input
          end
        else
          inputs
        end

      results =
        queryable
        |> source.run_batch.(query, col, coerced_inputs, repo_opts)
        |> Enum.map(cardinality_mapper)

      results =
        inputs
        |> Enum.zip(results)
        |> Map.new()

      {key, results}
    end

    defp run_batch({{:assoc, schema, pid, field, queryable, opts} = key, records}, source) do
      {ids, records} = Enum.unzip(records)
      query = source.query.(queryable, opts) |> Ecto.Queryable.to_query()
      repo_opts = Keyword.put(source.repo_opts, :caller, pid)
      empty = schema |> struct |> Map.fetch!(field)
      records = records |> Enum.map(&Map.put(&1, field, empty))

      results =
        if query.limit || query.offset || Enum.any?(query.order_bys) do
          records
          |> preload_lateral(field, query, source.repo, repo_opts)
        else
          records
          |> source.repo.preload([{field, query}], repo_opts)
        end

      results = results |> Enum.map(&Map.get(&1, field))
      {key, Map.new(Enum.zip(ids, results))}
    end

    def preload_lateral([], _assoc, _query, _opts), do: []

    def preload_lateral([%schema{} = struct | _] = structs, assoc, query, repo, repo_opts) do
      [pk] = schema.__schema__(:primary_key)

      # Carry the database prefix across from already-loaded records if not already set
      repo_opts = Keyword.put_new(repo_opts, :prefix, struct.__meta__.prefix)

      assocs = expand_assocs(schema, [assoc])
      query_excluding_preloads = exclude(query, :preload)

      inner_query =
        assocs
        |> Enum.reverse()
        |> build_preload_lateral_query(query_excluding_preloads, :join_first)
        |> maybe_distinct(assocs)

      results =
        from(x in schema,
          as: :parent,
          inner_lateral_join: y in subquery(inner_query),
          on: true,
          where: field(x, ^pk) in ^Enum.map(structs, &Map.get(&1, pk)),
          select: {field(x, ^pk), y}
        )
        |> repo.all(repo_opts)

      results =
        case query.preloads do
          [] ->
            results

          # Preloads can't be used in a subquery, using Repo.preload instead
          preloads ->
            {keys, vals} = Enum.unzip(results)
            vals = repo.preload(vals, preloads, repo_opts)
            Enum.zip(keys, vals)
        end

      {keyed, default} =
        case schema.__schema__(:association, assoc) do
          %{cardinality: :one} ->
            {results |> Map.new(), nil}

          %{cardinality: :many} ->
            {Enum.group_by(results, fn {k, _} -> k end, fn {_, v} -> v end), []}
        end

      structs
      |> Enum.map(&Map.put(&1, assoc, Map.get(keyed, Map.get(&1, pk), default)))
    end

    defp expand_assocs(_schema, []), do: []

    defp expand_assocs(schema, [assoc | rest]) do
      case schema.__schema__(:association, assoc) do
        %Ecto.Association.HasThrough{through: through} ->
          expand_assocs(schema, through ++ rest)

        a ->
          [a | expand_assocs(a.queryable, rest)]
      end
    end

    defp build_preload_lateral_query(
           [%Ecto.Association.ManyToMany{} = assoc],
           query,
           :join_first
         ) do
      [{owner_join_key, owner_key}, {related_join_key, related_key}] = assoc.join_keys

      join_query =
        query
        |> join(:inner, [x], y in ^assoc.join_through,
          on: field(x, ^related_key) == field(y, ^related_join_key)
        )
        |> where([..., x], field(x, ^owner_join_key) == field(parent_as(:parent), ^owner_key))

      binds_count = Ecto.Query.Builder.count_binds(join_query)

      join_query
      |> Ecto.Association.combine_joins_query(assoc.where, 0)
      |> Ecto.Association.combine_joins_query(assoc.join_where, binds_count - 1)
    end

    defp build_preload_lateral_query(
           [%Ecto.Association.ManyToMany{} = assoc],
           query,
           :join_last
         ) do
      [{owner_join_key, owner_key}, {related_join_key, related_key}] = assoc.join_keys

      join_query =
        query
        |> join(:inner, [..., x], y in ^assoc.join_through,
          on: field(x, ^related_key) == field(y, ^related_join_key)
        )
        |> where([..., x], field(x, ^owner_join_key) == field(parent_as(:parent), ^owner_key))

      binds_count = Ecto.Query.Builder.count_binds(join_query)

      join_query
      |> Ecto.Association.combine_joins_query(assoc.where, binds_count - 2)
      |> Ecto.Association.combine_joins_query(assoc.join_where, binds_count - 1)
    end

    defp build_preload_lateral_query([assoc], query, :join_first) do
      query
      |> where([x], field(x, ^assoc.related_key) == field(parent_as(:parent), ^assoc.owner_key))
      |> Ecto.Association.combine_assoc_query(assoc.where)
    end

    defp build_preload_lateral_query([assoc], query, :join_last) do
      join_query =
        query
        |> where(
          [..., x],
          field(x, ^assoc.related_key) == field(parent_as(:parent), ^assoc.owner_key)
        )

      binds_count = Ecto.Query.Builder.count_binds(join_query)

      join_query
      |> Ecto.Association.combine_joins_query(assoc.where, binds_count - 1)
    end

    defp build_preload_lateral_query(
           [%Ecto.Association.ManyToMany{} = assoc | rest],
           query,
           :join_first
         ) do
      [{owner_join_key, owner_key}, {related_join_key, related_key}] = assoc.join_keys

      join_query =
        query
        |> join(:inner, [x], y in ^assoc.join_through,
          on: field(x, ^related_key) == field(y, ^related_join_key)
        )
        |> join(:inner, [..., x], y in ^assoc.owner,
          on: field(x, ^owner_join_key) == field(y, ^owner_key)
        )

      binds_count = Ecto.Query.Builder.count_binds(join_query)

      query =
        join_query
        |> Ecto.Association.combine_joins_query(assoc.where, 0)
        |> Ecto.Association.combine_joins_query(assoc.join_where, binds_count - 2)

      build_preload_lateral_query(rest, query, :join_last)
    end

    defp build_preload_lateral_query(
           [%Ecto.Association.ManyToMany{} = assoc | rest],
           query,
           :join_last
         ) do
      [{owner_join_key, owner_key}, {related_join_key, related_key}] = assoc.join_keys

      join_query =
        query
        |> join(:inner, [..., x], y in ^assoc.join_through,
          on: field(x, ^related_key) == field(y, ^related_join_key)
        )
        |> join(:inner, [..., x], y in ^assoc.owner,
          on: field(x, ^owner_join_key) == field(y, ^owner_key)
        )

      binds_count = Ecto.Query.Builder.count_binds(join_query)

      query =
        join_query
        |> Ecto.Association.combine_joins_query(assoc.where, binds_count - 3)
        |> Ecto.Association.combine_joins_query(assoc.join_where, binds_count - 2)

      build_preload_lateral_query(rest, query, :join_last)
    end

    defp build_preload_lateral_query(
           [assoc | rest],
           query,
           :join_first
         ) do
      query =
        query
        |> join(:inner, [x], y in ^assoc.owner,
          on: field(x, ^assoc.related_key) == field(y, ^assoc.owner_key)
        )
        |> Ecto.Association.combine_joins_query(assoc.where, 0)

      build_preload_lateral_query(rest, query, :join_last)
    end

    defp build_preload_lateral_query(
           [assoc | rest],
           query,
           :join_last
         ) do
      binds_count = Ecto.Query.Builder.count_binds(query)

      join_query =
        query
        |> Ecto.Association.combine_joins_query(assoc.where, binds_count - 1)
        |> join(:inner, [..., x], y in ^assoc.owner,
          on: field(x, ^assoc.related_key) == field(y, ^assoc.owner_key)
        )

      build_preload_lateral_query(rest, join_query, :join_last)
    end

    defp maybe_distinct(%Ecto.Query{distinct: dist} = query, _) when dist, do: query

    defp maybe_distinct(query, [%Ecto.Association.Has{}, %Ecto.Association.BelongsTo{} | _]),
      do: distinct(query, true)

    defp maybe_distinct(query, [%Ecto.Association.ManyToMany{} | _]), do: distinct(query, true)

    defp maybe_distinct(query, [_assoc | rest]), do: maybe_distinct(query, rest)
    defp maybe_distinct(query, []), do: query

    defp emit_start_event(id, system_time, batch) do
      :telemetry.execute(
        [:dataloader, :source, :batch, :run, :start],
        %{system_time: system_time},
        %{id: id, batch: batch}
      )
    end

    defp emit_stop_event(id, start_time_mono, batch) do
      :telemetry.execute(
        [:dataloader, :source, :batch, :run, :stop],
        %{duration: System.monotonic_time() - start_time_mono},
        %{id: id, batch: batch}
      )
    end

    defp cardinality_mapper(:many, _) do
      fn
        value when is_list(value) -> value
        value -> [value]
      end
    end

    defp cardinality_mapper(:one, queryable) do
      fn
        [] ->
          nil

        [value] ->
          value

        other when is_list(other) ->
          raise Ecto.MultipleResultsError, queryable: queryable, count: length(other)

        other ->
          other
      end
    end

    # Optionally use `async_stream/3` function from
    # `opentelemetry_process_propagator` if available
    if Code.ensure_loaded?(OpentelemetryProcessPropagator.Task) do
      @spec async_stream(Enumerable.t(), (term -> term), keyword) :: Enumerable.t()
      defdelegate async_stream(items, fun, opts), to: OpentelemetryProcessPropagator.Task
    else
      @spec async_stream(Enumerable.t(), (term -> term), keyword) :: Enumerable.t()
      defdelegate async_stream(items, fun, opts), to: Task
    end
  end
end
