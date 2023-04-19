defmodule Dx.Defd.Ast do
  def ensure_args_loaded(ast, list, state) when is_list(list) do
    ast =
      quote do
        unquote(list)
        |> Dx.Defd.Result.map()
        |> Dx.Defd.Result.then(fn _ -> unquote(ast) end)
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
