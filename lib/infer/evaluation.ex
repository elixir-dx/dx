defmodule Infer.Evaluation do
  @moduledoc """
  Represents an evaluation run in `Infer.Engine` according to the
  [token pattern](https://rrrene.org/2018/03/26/flow-elixir-using-plug-like-token/)
  in Elixir.
  """
  use TypedStruct

  typedstruct do
    field(:root_subject, map())

    # Options
    field(:args, map(), default: %{})
    field(:debug?, boolean(), default: false)
    field(:preload, boolean(), default: false)
    field(:extra_rules, list(module()), default: [])
  end

  def from_options(opts) do
    %__MODULE__{} |> add_options(opts)
  end

  def add_options(eval, opts) do
    Enum.reduce(opts, eval, fn
      {:extra_rules, mods}, eval -> %{eval | extra_rules: List.wrap(mods)}
      {:debug, debug}, eval -> %{eval | debug?: debug}
      {:args, args}, eval -> %{eval | args: Map.new(args)}
      {key, val}, eval -> Map.replace!(eval, key, val)
    end)
  end
end
