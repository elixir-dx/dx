defmodule Dx.Loaders.Dataloader do
  @moduledoc """
  Uses `Dataloader` to load missing data incrementally.

  ## Supported options

  These options are passed to `Dataloader.Ecto.new/2`:

  - **timeout** Timeout in milliseconds for `Dataloader` to wait for all data to be loaded. Defaults to 15_000.
  - **repo_options** Options passed to the `Ecto.Repo` when loading data. Defaults to `[]`.
  """

  alias Dx.Result

  # Query = Wrapper around Loader ✅
  # 1. extract the part that can be translated to query
  #   -> can use lookup, may return {:not_loaded, data_reqs}
  # 2. pass translatable part to lookup (unchanged)
  # 3. later: optimize batching
  # 4. on successful lookup, if not all translated, return {:partial, result, condition} for Dx.Engine
  def lookup(cache, data_req) do
    case apply(Dataloader, :get, [cache | args_for(data_req)]) do
      {:error, "Unable to find " <> _} ->
        # try to translate to query here
        #   -> loader needs eval, pass it in/through
        # how to ensure optimized batching can happen here?
        {:not_loaded, MapSet.new([data_req])}

      {:ok, result} ->
        Result.ok(result)

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

  defp where(opts, []), do: opts
  defp where(opts, conditions), do: Keyword.put(opts, :where, {:all, conditions})

  def init(opts \\ []) do
    repo = config(:repo)

    ecto_opts = [
      query: &Dx.Ecto.Query.from_options/2,
      repo_opts: opts[:repo_options] || opts[:repo_opts] || [],
      timeout: opts[:timeout] || Dataloader.default_timeout()
    ]

    source = Dataloader.Ecto.new(repo, ecto_opts)

    Dataloader.new(get_policy: :tuples)
    |> Dataloader.add_source(:assoc, source)
  end

  def load(cache, data_reqs) do
    Enum.reduce(data_reqs, cache, fn data_req, cache ->
      apply(Dataloader, :load, [cache | args_for(data_req)])
    end)
    |> Dataloader.run()
  end

  def config(:repo), do: Application.fetch_env!(:dx, :repo)
end
