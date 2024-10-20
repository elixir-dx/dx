defmodule Dx.Defd.Kernel do
  @moduledoc false

  alias Dx.Defd.Ast
  alias Dx.Defd.Compiler

  def rewrite(
        {:&, meta, [{:/, [], [{{:., _meta2, [:erlang, fun_name]}, _meta3, []}, arity]}]},
        state
      ) do
    ast =
      cond do
        function_exported?(__MODULE__, fun_name, arity) ->
          args = Macro.generate_arguments(arity, __MODULE__)
          line = meta[:line] || state.line

          quote line: line do
            {:ok,
             fn unquote_splicing(args) ->
               unquote(__MODULE__).unquote(fun_name)(unquote_splicing(args))
             end}
          end

        true ->
          args = Macro.generate_arguments(arity, __MODULE__)
          line = meta[:line] || state.line

          quote line: line do
            {:ok,
             fn unquote_splicing(args) ->
               {:ok, unquote(:erlang).unquote(fun_name)(unquote_splicing(args))}
             end}
          end
      end

    {ast, state}
  end

  def rewrite({{:., meta, [:erlang, fun_name]}, meta2, orig_args} = orig, state) do
    arity = length(orig_args)

    {args, state} = Enum.map_reduce(orig_args, state, &Compiler.normalize_load_unwrap/2)
    {args, state} = Compiler.finalize_args(args, state)

    ast =
      cond do
        Enum.all?(args, &Ast.ok?/1) ->
          args = Enum.map(args, &Ast.unwrap_inner/1)

          quote do
            unquote({:ok, {{:., meta, [:erlang, fun_name]}, meta2, args}})
          end

        function_exported?(:erlang, fun_name, arity) ->
          Compiler.compile_error!(meta, state, """
          #{fun_name}/#{arity} is not supported by Dx yet.

          Please check the issues in the repo, upvote, comment, or create an issue for it.
          """)

        true ->
          {:ok, orig}
      end

    {ast, state}
  end

  import Kernel, except: [==: 2]
  import Dx.Defd.Ext

  defscope unquote(:==)({:error, _left}, _right, generate_fallback) do
    {:error, generate_fallback.()}
  end

  defscope unquote(:==)(_left, {:error, _right}, generate_fallback) do
    {:error, generate_fallback.()}
  end

  defscope unquote(:==)(left, right, generate_fallback) do
    quote do
      {:eq, unquote(left), unquote(right), unquote(generate_fallback.())}
    end
  end

  defscope unquote(:not)(term, _generate_fallback) do
    {:not, term}
  end

  def is_function(%Dx.Defd.Fn{}) do
    true
  end

  def is_function(term) do
    :erlang.is_function(term)
  end

  def is_function(term, arity) do
    :erlang.is_function(term, arity)
  end
end
