defmodule Infer.Loaders.Dataloader do
  @moduledoc """
  Uses `Dataloader` to load missing data incrementally.
  """

  alias Infer.Result

  def lookup(cache, data_req) do
    case apply(Dataloader, :get, [cache | args_for(data_req)]) do
      {:error, "Unable to find " <> _} -> {:not_loaded, MapSet.new([data_req])}
      {:ok, result} -> Result.ok(result)
      other -> other
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

  def init() do
    # workaround for dataloader incompatibility with transactions
    #   -> https://github.com/absinthe-graphql/dataloader/issues/129#issuecomment-965492108
    run_concurrently? = not db_conn_checked_out?(Ev2.Repo)

    source =
      Dataloader.Ecto.new(Ev2.Repo,
        query: &Infer.Ecto.Query.from_options/2,
        async: run_concurrently?
      )

    Dataloader.new(get_policy: :tuples, async: run_concurrently?)
    |> Dataloader.add_source(:assoc, source)
  end

  defp db_conn_checked_out?(repo_name) do
    {adapter, meta} = Ecto.Repo.Registry.lookup(repo_name)
    adapter.checked_out?(meta)
  end

  def load(cache, data_reqs) do
    Enum.reduce(data_reqs, cache, fn data_req, cache ->
      apply(Dataloader, :load, [cache | args_for(data_req)])
    end)
    |> Dataloader.run()
  end
end
