defmodule Infer.Loaders.Dataloader do
  @moduledoc """
  Uses `Dataloader` to load missing data incrementally.
  """

  def lookup(cache, :assoc, subject, key) do
    case Dataloader.get(cache, :assoc, key, subject) do
      {:error, "Unable to find batch " <> _} -> {:not_loaded, [{:assoc, subject, key}]}
      other -> other
    end
  end

  def init() do
    source = Dataloader.Ecto.new(Ev2.Repo)

    Dataloader.new(get_policy: :tuples)
    |> Dataloader.add_source(:assoc, source)
  end

  def load(cache, data_reqs) do
    Enum.reduce(data_reqs, cache, fn
      {:assoc, subject, key}, cache -> Dataloader.load(cache, :assoc, key, subject)
    end)
    |> Dataloader.run()
  end
end
