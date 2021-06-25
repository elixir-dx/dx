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

  defp args_for({:query_one, type, [main_condition | other_conditions], _opts}) do
    [:assoc, {:one, type, where: other_conditions}, [main_condition]]
  end

  defp args_for({:query_first, type, [main_condition | other_conditions], opts}) do
    opts = opts |> Keyword.put(:where, other_conditions) |> Keyword.put(:limit, 1)
    [:assoc, {:one, type, opts}, [main_condition]]
  end

  defp args_for({:query_all, type, [main_condition | other_conditions], opts}) do
    opts = Keyword.put(opts, :where, other_conditions)
    [:assoc, {:many, type, opts}, [main_condition]]
  end

  def init() do
    source = Dataloader.Ecto.new(Ev2.Repo, query: &Infer.Ecto.Query.from_options/2)

    Dataloader.new(get_policy: :tuples)
    |> Dataloader.add_source(:assoc, source)
  end

  def load(cache, data_reqs) do
    Enum.reduce(data_reqs, cache, fn data_req, cache ->
      apply(Dataloader, :load, [cache | args_for(data_req)])
    end)
    |> Dataloader.run()
  end
end
