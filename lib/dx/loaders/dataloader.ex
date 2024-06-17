defmodule Dx.Loaders.Dataloader do
  @moduledoc """
  Uses `Dataloader` to load missing data incrementally.
  """

  alias Dx.Result

  # Query = Wrapper around Loader ✅
  # 1. extract the part that can be translated to query
  #   -> can use lookup, may return {:not_loaded, data_reqs}
  # 2. pass translatable part to lookup (unchanged)
  # 3. later: optimize batching
  # 4. on successful lookup, if not all translated, return {:partial, result, condition} for Dx.Engine
  def lookup(cache, data_req, third_elem \\ true)

  def lookup(cache, {:subset, %type{} = subject, subset}, third_elem) do
    assocs = type.__schema__(:associations)

    # for all key-value pairs in current map ...
    Enum.reduce_while(subset, {:ok, subject}, fn {field, subset}, acc ->
      if field in assocs do
        result =
          with {:ok, nested_value} <- fetch(cache, subject, field, third_elem),
               {:ok, loaded_value} <- lookup(cache, {:subset, nested_value, subset}, third_elem) do
            {:ok, Map.put(subject, field, loaded_value)}
          end

        Dx.Defd.Result.merge(acc, result)
      else
        {:cont, acc}
      end
    end)
  end

  def lookup(_cache, {:subset, subject, _subset}, third_elem) do
    if third_elem, do: Result.ok(subject), else: Dx.Defd.Result.ok(subject)
  end

  def lookup(cache, %Dx.Scope{} = scope, third_elem) do
    case apply(Dataloader, :get, [cache | args_for(scope)]) do
      {:error, "Unable to find " <> _} ->
        # try to translate to query here
        #   -> loader needs eval, pass it in/through
        # how to ensure optimized batching can happen here?
        {:not_loaded, MapSet.new([scope])}

      {:ok, data} ->
        if third_elem, do: Result.ok(data), else: Dx.Defd.Result.ok(data)

      # if third_elem,
      #   do: Result.ok(%Dx.Scope.Loaded{data: data, scope: scope}),
      #   else: Dx.Defd.Result.ok(%Dx.Scope.Loaded{data: data, scope: scope})

      other ->
        other
    end
  end

  def lookup(cache, data_req, third_elem) do
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

  defp fetch(cache, subject, key, third_elem) do
    case Map.fetch!(subject, key) do
      %Ecto.Association.NotLoaded{} ->
        lookup(cache, {:assoc, subject, key}, third_elem)

      result ->
        if third_elem, do: Result.ok(result), else: Dx.Defd.Result.ok(result)
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

  # defp args_for(%Dx.Scope{
  #        cardinality: :all,
  #        type: type,
  #        query_conditions: [],
  #        opts: opts
  #      }) do
  #   [:assoc, {:many, type, opts}, []]
  # end

  # defp args_for(%Dx.Scope{
  #        cardinality: :all,
  #        type: type,
  #        query_conditions: conditions,
  #        opts: opts
  #      }) do
  #   [main_condition | other_conditions] = Dx.Scope.resolve_conditions(conditions)
  #   opts = opts |> where(other_conditions)
  #   [:assoc, {:many, type, opts}, [main_condition]]
  # end
  defp args_for(%Dx.Scope{} = scope) do
    {main_condition, other_conditions} = Dx.Scope.split_main_condition(scope)
    scope = %{scope | query_conditions: other_conditions}
    [:dx_scope, {:many, scope.type, scope: scope}, main_condition]
  end

  defp where(opts, []), do: opts
  defp where(opts, conditions), do: Keyword.put(opts, :where, {:all, conditions})

  def init() do
    repo = config(:repo)

    # workaround for dataloader incompatibility with transactions
    #   -> https://github.com/absinthe-graphql/dataloader/issues/129#issuecomment-965492108
    run_concurrently? = not db_conn_checked_out?(repo)

    source =
      Dx.Ecto.DataloaderSource.new(repo,
        query: &Dx.Ecto.Query.from_options/2,
        # run_batch: &run_batch/5,
        async: run_concurrently?
      )

    scope_source =
      Dx.Ecto.DataloaderSource.new(repo,
        query: &Dx.Ecto.Scope.to_query/2,
        # run_batch: &run_batch/5,
        async: run_concurrently?
      )

    Dataloader.new(get_policy: :tuples, async: run_concurrently?)
    |> Dataloader.add_source(:assoc, source)
    |> Dataloader.add_source(:dx_scope, scope_source)
  end

  defp db_conn_checked_out?(repo_name) do
    case Ecto.Repo.Registry.lookup(repo_name) do
      # Ecto < 3.8.0
      {adapter, meta} -> adapter.checked_out?(meta)
      # Ecto >= 3.8.0
      %{adapter: adapter} = meta -> adapter.checked_out?(meta)
    end
  end

  def load(cache, data_reqs) do
    Enum.reduce(data_reqs, cache, fn data_req, cache ->
      apply(Dataloader, :load, [cache | args_for(data_req)])
    end)
    |> Dataloader.run()
  end

  def config(:repo), do: Application.fetch_env!(:dx, :repo)
end
