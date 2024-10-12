# Uses `Dataloader` to load missing data incrementally.
#
# ## Supported options
#
# These options are passed to `Dataloader.Ecto.new/2`:
#
# - `timeout` - Timeout in milliseconds for `Dataloader` to wait for all data to be loaded. Defaults to 15_000.
# - `repo_options` - Options passed to the `Ecto.Repo` when loading data. Defaults to `[]`.
#
defmodule Dx.Loaders.Dataloader do
  @moduledoc false

  alias Dx.Ecto.Query.Batches
  alias Dx.Result

  def lookup(cache, data_req, third_elem \\ true)

  def lookup({cache, meta}, %Dx.Scope{} = scope, third_elem) do
    {candidates, temp_scope} = Dx.Scope.extract_main_condition_candidates(scope)

    Map.fetch(meta, temp_scope)
    |> case do
      {:ok, scope_meta} -> Map.fetch(scope_meta, candidates)
      :error -> :error
    end
    |> case do
      {:ok, main_condition_field} ->
        apply(Dataloader, :get, [
          cache | args_for(temp_scope, candidates, main_condition_field)
        ])

      :error ->
        Enum.find_value(candidates, nil, fn {field, _value} ->
          case apply(Dataloader, :get, [cache | args_for(temp_scope, candidates, field)]) do
            {:error, "Unable to find " <> _} -> nil
            {:ok, data} -> {:ok, data}
          end
        end)
    end
    |> case do
      nil ->
        {:not_loaded, Dx.Scope.to_data_req(scope)}

      {:error, "Unable to find " <> _} ->
        # try to translate to query here
        #   -> loader needs eval, pass it in/through
        # how to ensure optimized batching can happen here?
        {:not_loaded, Dx.Scope.to_data_req(scope)}

      {:ok, data} ->
        if third_elem, do: Result.ok(data), else: Dx.Defd.Result.ok(data)

      other ->
        other
    end
  end

  def lookup({cache, _}, data_req, third_elem) do
    case apply(Dataloader, :get, [cache | args_for(data_req)]) do
      {:error, "Unable to find " <> _} ->
        # try to translate to query here
        #   -> loader needs eval, pass it in/through
        # how to ensure optimized batching can happen here?
        {:not_loaded, MapSet.new([data_req])}

      {:ok, result} ->
        if third_elem, do: Result.ok(result), else: Dx.Defd.Result.ok(result)

      other ->
        other
    end
  end

  defp args_for({:assoc, subject, key}) do
    [:assoc, key, subject]
  end

  defp args_for({:query_one, type, [main_condition | other_conditions], opts}) do
    opts = opts |> where(other_conditions)
    [:assoc, {:one, type, opts}, [main_condition]]
  end

  defp args_for({:query_first, type, [main_condition | other_conditions], opts}) do
    opts = opts |> where(other_conditions) |> Keyword.put(:limit, 1)
    [:assoc, {:one, type, opts}, [main_condition]]
  end

  defp args_for({:query_all, type, [main_condition | other_conditions], opts}) do
    opts = opts |> where(other_conditions)
    [:assoc, {:many, type, opts}, [main_condition]]
  end

  defp args_for(%Dx.Scope{} = scope, combination, nil) do
    scope = Dx.Scope.add_conditions(scope, combination)
    [:dx_scope, {scope.cardinality, scope.type, scope: scope}, []]
  end

  defp args_for(%Dx.Scope{} = scope, combination, main_condition_field) do
    {main_condition_value, other_conditions} = Map.pop!(combination, main_condition_field)
    scope = Dx.Scope.add_conditions(scope, other_conditions)
    main_condition = [{main_condition_field, main_condition_value}]
    [:dx_scope, {scope.cardinality, scope.type, scope: scope}, main_condition]
  end

  defp where(opts, []), do: opts
  defp where(opts, conditions), do: Keyword.put(opts, :where, {:all, conditions})

  def init(opts \\ []) do
    repo = config(:repo)

    source =
      Dataloader.Ecto.new(repo,
        query: &Dx.Ecto.Query.from_options/2,
        repo_opts: opts[:repo_options] || opts[:repo_opts] || [],
        timeout: opts[:timeout] || Dataloader.default_timeout()
      )

    scope_source =
      Dx.Ecto.DataloaderSource.new(repo,
        query: &Dx.Ecto.Scope.to_query/2,
        run_batch: &run_batch(config(:repo), &1, &2, &3, &4, &5),
        repo_opts: opts[:repo_options] || opts[:repo_opts] || [],
        timeout: opts[:timeout] || Dataloader.default_timeout()
      )

    loader =
      Dataloader.new(get_policy: :tuples)
      |> Dataloader.add_source(:assoc, source)
      |> Dataloader.add_source(:dx_scope, scope_source)

    {loader, %{}}
  end

  def load({cache, meta}, data_reqs) do
    batches =
      data_reqs
      |> Enum.reduce(Batches.new(), fn
        {scope, combinations}, batches ->
          Enum.reduce(combinations, batches, fn combination, batches ->
            Batches.add_filters(batches, scope, combination)
          end)

        _other, batches ->
          batches
      end)
      |> Batches.get_batches()

    meta =
      Enum.reduce(batches, meta, fn
        {scope, scope_batches}, meta ->
          Enum.reduce(scope_batches, meta, fn
            {}, meta ->
              Batches.map_put_in(meta, [scope, %{}], nil)

            {batch_field, batch_values, other_filters}, meta ->
              new_entries =
                Map.new(batch_values, fn value ->
                  combination = Map.new([{batch_field, value} | other_filters])
                  {combination, batch_field}
                end)

              Map.update(meta, scope, new_entries, &Map.merge(&1, new_entries))
          end)

        _other, meta ->
          meta
      end)

    cache =
      Enum.reduce(data_reqs, cache, fn
        {scope, combinations}, cache ->
          Enum.reduce(combinations, cache, fn combination, cache ->
            apply(Dataloader, :load, [
              cache | args_for(scope, combination, meta[scope][combination])
            ])
          end)

        data_req, cache ->
          apply(Dataloader, :load, [cache | args_for(data_req)])
      end)
      |> Dataloader.run()

    {cache, meta}
  end

  def config(:repo), do: Application.fetch_env!(:dx, :repo)

  # Source overrides

  # no main condition
  def run_batch(repo, _queryable, {query, scope}, nil, [nil], repo_opts) do
    case {scope.aggregate?, scope.cardinality, repo.all(query, repo_opts)} do
      {true, :one, [result]} -> [{result.result, scope}]
      {_, :one, []} -> [{nil, scope}]
      {_, :one, [result]} -> [{result, scope}]
      {_, :many, results} -> [{results, scope}]
    end
  end

  # aggregate
  def run_batch(repo, _queryable, {query, %{aggregate?: true} = scope}, col, inputs, repo_opts) do
    import Ecto.Query

    expr = dynamic([x], field(x, ^col))

    grouped_results =
      query
      |> group_by(^expr)
      |> select_merge(^%{col => expr})
      |> repo.all(repo_opts)
      |> Map.new(&{Map.fetch!(&1, col), &1.result})

    scope = %{scope | cardinality: :many}

    for value <- inputs do
      {Map.get(grouped_results, value, scope.aggregate_default), scope}
    end
  end

  # all other cases
  def run_batch(repo, queryable, {query, scope}, col, inputs, repo_opts) do
    Dx.Ecto.DataloaderSource.run_batch(
      repo,
      queryable,
      query,
      col,
      inputs,
      repo_opts
    )
    |> Enum.map(&{&1, scope})
  end
end
