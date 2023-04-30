defmodule Dx.Defd.Ast do
  def ensure_loaded(ast, data_reqs, state) do
    {loaders, vars} = Enum.unzip(data_reqs)
    ensure_loaded(ast, loaders, vars, state)
  end

  def ensure_loaded(ast, [], _vars, state) do
    {ast, state}
  end

  def ensure_loaded(ast, [loader], [var], state) do
    ast =
      quote do
        case unquote(loader) do
          {:ok, unquote(var)} -> unquote(ast)
          other -> other
        end
      end

    {ast, state}
  end

  def ensure_loaded(ast, list, vars, state) when is_list(list) do
    ast =
      quote do
        case Dx.Defd.Result.collect_reverse(unquote(list)) do
          {:ok, unquote(Enum.reverse(vars))} -> unquote(ast)
          other -> other
        end
      end

    {ast, state}
  end

  def unwrap({:ok, ast}) do
    ast
  end

  def unwrap(ast) do
    quote do
      Dx.Result.unwrap!(unquote(ast))
    end
  end
end
