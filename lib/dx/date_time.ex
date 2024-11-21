defmodule Dx.DateTime do
  @moduledoc false

  use Dx.Defd.Ext

  @impl true
  def __fun_info(_fun_name, arity) do
    %FunInfo{args: List.duplicate(:preload_scope, arity)}
  end

  defscope after?(left, right, generate_fallback) do
    quote do: {:gt, unquote(left), unquote(right), unquote(generate_fallback.())}
  end

  defscope before?(left, right, generate_fallback) do
    quote do: {:lt, unquote(left), unquote(right), unquote(generate_fallback.())}
  end

  defscope compare(left, right, generate_fallback) do
    quote do: {:compare, unquote(left), unquote(right), unquote(generate_fallback.())}
  end
end
