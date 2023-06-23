defmodule Dx.Defd.Kernel do
  alias Dx.Defd.Ast
  alias Dx.Defd.Compiler

  def rewrite({{:., meta, [:erlang, fun_name]}, meta2, args}, state) do
    {args, state} = Enum.map_reduce(args, state, &Compiler.normalize/2)
    args = if state.in_external? and state.in_fn?, do: args, else: Enum.map(args, &Ast.unwrap/1)

    ast = {{:., meta, [:erlang, fun_name]}, meta2, args}
    ast = if state.in_external? and state.in_fn?, do: ast, else: {:ok, ast}

    {ast, state}
  end

  def rewrite(ast, state) do
    {ast, state}
  end
end
