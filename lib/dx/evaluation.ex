defmodule Dx.Evaluation do
  @moduledoc """
  Holds run options and already loaded data passed between `Dx.Defd`-defined functions according to the
  [token pattern](https://rrrene.org/2018/03/26/flow-elixir-using-plug-like-token/)
  in Elixir.

  This is also used in the now deprecated `infer` approach of Dx.
  """

  use TypedStruct

  typedstruct do
    field(:root_subject, map())
    field(:cache, any())
    field(:return_cache?, boolean(), default: false)
    field(:finalize?, boolean(), default: true)
    field(:binds, map())
    field(:negate?, boolean(), default: false)
    field(:resolve_predicates?, boolean(), default: true)

    # Options
    field(:loader, module(), default: Dx.Loaders.Dataloader)
    field(:loader_options, Keyword.t(), default: [])
    field(:args, map(), default: %{})
    field(:debug?, boolean(), default: false)
    field(:extra_rules, list(module()), default: [])
    field(:select, any())
  end

  def from_options(opts) do
    %__MODULE__{}
    |> add_options(opts)
    |> case do
      %{cache: nil} = eval -> Map.put(eval, :cache, eval.loader.init(eval.loader_options))
      other -> other
    end
  end

  def add_options(eval, opts) do
    Enum.reduce(opts, eval, fn
      {:extra_rules, mods}, eval -> %{eval | extra_rules: List.wrap(mods)}
      {:debug, debug}, eval -> %{eval | debug?: debug}
      {:return_cache, return_cache}, eval -> %{eval | return_cache?: return_cache}
      {:args, args}, eval -> %{eval | args: Map.new(args)}
      {key, val}, eval -> %{eval | key => val}
    end)
  end

  @doc false
  def load_data_reqs(eval, data_reqs) do
    Map.update!(eval, :cache, &eval.loader.load(&1, data_reqs))
  end

  @doc false
  def load_all_data_reqs!(eval_opts, fun) when is_list(eval_opts) do
    from_options(eval_opts)
    |> load_all_data_reqs(fun)
    |> Dx.Result.unwrap!()
  end

  def load_all_data_reqs!(eval, fun) do
    eval
    |> load_all_data_reqs(fun)
    |> Dx.Result.unwrap!()
  end

  @doc false
  def load_all_data_reqs(eval_opts, fun) when is_list(eval_opts) do
    from_options(eval_opts)
    |> load_all_data_reqs(fun)
  end

  def load_all_data_reqs(eval, fun) do
    case {fun.(eval), eval.finalize?} do
      {{:not_loaded, data_reqs}, _} ->
        load_data_reqs(eval, data_reqs) |> load_all_data_reqs(fun)

      {{:ok, result, _binds}, _} ->
        {:ok, result, eval.cache}

      {{:ok, result}, true} ->
        load_all_data_reqs(%{eval | finalize?: false}, &Dx.Defd.Runtime.finalize(result, &1))

      {{:error, :timeout}, _} ->
        {:error, %Dx.Error.Timeout{configured_timeout: eval.loader_options[:timeout]}}

      {other, _} ->
        other
    end
  rescue
    e ->
      # Remove Dx's inner stacktrace and convert defd function names
      Dx.Defd.Error.filter_and_reraise(e, __STACKTRACE__)
  end
end
