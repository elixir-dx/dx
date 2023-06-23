defmodule Dx.Enum do
  alias Dx.Defd.Ast
  alias Dx.Defd.Compiler
  alias Dx.Defd.Result

  def rewrite({{:., meta, [Enum, fun_name]}, meta2, args}, state) do
    {args, state} = Enum.map_reduce(args, state, &Compiler.normalize/2)
    args = Enum.map(args, &Ast.unwrap/1)

    {{{:., meta, [__MODULE__, fun_name]}, meta2, args}, state}
  end

  def rewrite(ast, state) do
    {ast, state}
  end

  def map(enum, mapper) do
    Result.collect(Enum.map(enum, mapper))
  end
end
