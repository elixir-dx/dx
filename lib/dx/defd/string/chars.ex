defmodule Dx.Defd.String.Chars do
  @moduledoc false

  alias Dx.Defd.Ast
  alias Dx.Defd.Compiler

  def rewrite(
        {:&, meta, [{:/, [], [{{:., _meta2, [String.Chars, fun_name]}, _meta3, []}, arity]}]},
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
               {:ok, unquote(String.Chars).unquote(fun_name)(unquote_splicing(args))}
             end}
          end
      end

    {ast, state}
  end

  def rewrite({{:., meta, [String.Chars, fun_name]}, meta2, orig_args} = orig, state) do
    arity = length(orig_args)

    {args, state} = Enum.map_reduce(orig_args, state, &Compiler.normalize_load_unwrap/2)
    {args, state} = Compiler.finalize_args(args, state)

    ast =
      cond do
        Enum.all?(args, &Ast.ok?/1) ->
          args = Enum.map(args, &Ast.unwrap_inner/1)

          quote do
            unquote({:ok, {{:., meta, [String.Chars, fun_name]}, meta2, args}})
          end

        function_exported?(String.Chars, fun_name, arity) ->
          Compiler.compile_error!(meta, state, """
          #{fun_name}/#{arity} is not supported by Dx yet.

          Please check the issues in the repo, upvote, comment, or create an issue for it.
          """)

        true ->
          {:ok, orig}
      end

    {ast, state}
  end
end
