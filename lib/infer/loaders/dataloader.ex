defmodule Infer.Loaders.Dataloader do
  @moduledoc """
  Uses `Dataloader` to load missing data incrementally.
  """

  alias Infer.Result

  def lookup(cache, :assoc, subject, key) do
    case Dataloader.get(cache, :assoc, key, subject) do
      {:error, "Unable to find " <> _} -> {:not_loaded, MapSet.new([{:assoc, subject, key}])}
      {:ok, result} -> Result.ok(result)
      other -> other
    end
  end

  def lookup(cache, :query_one, type, main_key, main_value, conditions, options) do
    case Dataloader.get(cache, :assoc, {:one, type, Keyword.put(options, :where, conditions)}, [
           {main_key, main_value}
         ]) do
      {:error, "Unable to find " <> _} ->
        {:not_loaded, MapSet.new([{:one, type, main_key, main_value, conditions, options}])}

      {:ok, result} ->
        Result.ok(result)

      other ->
        other
    end
  end

  def to_query(type, options) when options == %{} do
    type
  end

  def to_query(type, options) do
    Infer.Ecto.Query.to_condition(type, options[:where])
  end

  def init() do
    source = Dataloader.Ecto.new(Ev2.Repo, query: &to_query/2)

    Dataloader.new(get_policy: :tuples)
    |> Dataloader.add_source(:assoc, source)
  end

  def load(cache, data_reqs) do
    Enum.reduce(data_reqs, cache, fn
      {:assoc, subject, key}, cache ->
        Dataloader.load(cache, :assoc, key, subject)

      {:one, type, main_key, main_value, conditions, options}, cache ->
        Dataloader.load(cache, :assoc, {:one, type, Keyword.put(options, :where, conditions)}, [
          {main_key, main_value}
        ])
    end)
    |> Dataloader.run()
  end
end
