defmodule Dx.Defd.Ast do
  def ensure_loaded(ast, data_reqs) do
    {loaders, vars} = Enum.unzip(data_reqs)
    ensure_loaded(ast, loaders, vars)
  end

  def ensure_loaded(ast, [], _vars) do
    ast
  end

  def ensure_loaded(ast, [loader], [var]) do
    quote do
      case unquote(loader) do
        {:ok, unquote(var)} -> unquote(ast)
        other -> other
      end
    end
  end

  def ensure_loaded(ast, list, vars) do
    quote do
      case Dx.Defd.Result.collect_reverse(unquote(list), {:ok, []}) do
        {:ok, unquote(Enum.reverse(vars))} -> unquote(ast)
        other -> other
      end
    end
  end

  def unwrap({:ok, ast}) do
    ast
  end

  def unwrap(ast) do
    quote do
      Dx.Result.unwrap!(unquote(ast))
    end
  end

  def fetch({:ok, ast}, key, eval) do
    quote do
      Dx.Defd.Util.fetch(unquote(ast), unquote(key), unquote(eval))
    end
  end

  def fetch(ast, key, eval) do
    quote do
      Dx.Defd.Util.maybe_fetch(unquote(ast), unquote(key), unquote(eval))
    end
  end
end
