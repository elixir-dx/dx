defmodule Infer.Evaluation do
  @moduledoc """
  Represents an evaluation run in `Infer.Engine` according to the
  [token pattern](https://rrrene.org/2018/03/26/flow-elixir-using-plug-like-token/)
  in Elixir.
  """
  use TypedStruct

  typedstruct do
    field(:root_subject, map())
    field(:cache, any())
    field(:binds, map())
    field(:negate?, boolean(), default: false)
    field(:resolve_predicates?, boolean(), default: true)

    # Options
    field(:loader, module(), default: Infer.Loaders.Dataloader)
    field(:args, map(), default: %{})
    field(:debug?, boolean(), default: false)
    field(:preload, boolean(), default: false)
    field(:extra_rules, list(module()), default: [])
    field(:select, any())
  end

  def from_options(opts) do
    %__MODULE__{}
    |> add_options(opts)
    |> case do
      %{cache: nil} = eval -> Map.put(eval, :cache, eval.loader.init())
      other -> other
    end
  end

  def add_options(eval, opts) do
    Enum.reduce(opts, eval, fn
      {:extra_rules, mods}, eval -> %{eval | extra_rules: List.wrap(mods)}
      {:debug, debug}, eval -> %{eval | debug?: debug}
      {:args, args}, eval -> %{eval | args: Map.new(args)}
      {key, val}, eval -> Map.replace!(eval, key, val)
    end)
  end

  @doc """
  Loads the given data requirements in an evaluation, and returns it updated.
  """
  def load_data_reqs(eval, data_reqs) do
    Map.update!(eval, :cache, &eval.loader.load(&1, data_reqs))
  end
end
