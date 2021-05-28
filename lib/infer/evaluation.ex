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

    # Options
    field(:loader, module(), default: Infer.Loaders.Dataloader)
    field(:args, map(), default: %{})
    field(:debug?, boolean(), default: false)
    field(:preload, boolean(), default: false)
    field(:extra_rules, list(module()), default: [])
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

  @doc """
  Calls `fun` repeatedly as long as it returns `{:not_loaded, data_reqs}`, loading the
  `data_reqs` between each call. Finally returns the result of the last call.

  `fun` must take a single argument, the `Infer.Evaluation`.
  """
  def load_while_data_reqs(opts, fun) when is_list(opts) do
    eval = from_options(opts)

    load_while_data_reqs(eval, fun)
  end

  def load_while_data_reqs(eval, fun) do
    case fun.(eval) do
      {:not_loaded, data_reqs} -> load_data_reqs(eval, data_reqs) |> load_while_data_reqs(fun)
      result -> result
    end
  end
end
