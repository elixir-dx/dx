defmodule Dx.Defd.Kernel do
  @moduledoc false

  use Dx.Defd.Ext

  @impl true
  def __fun_info(_fun_name, arity) do
    %FunInfo{args: List.duplicate(:preload_scope, arity)}
  end

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

  def apply(%Dx.Defd.Fn{fun: fun}, args) do
    Kernel.apply(fun, args)
  end

  def apply(fun, args) do
    Kernel.apply(fun, args)
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

  def is_function(%Dx.Defd.Fn{fun: fun}, arity) do
    :erlang.is_function(fun, arity)
  end

  def is_function(term, arity) do
    :erlang.is_function(term, arity)
  end
end
