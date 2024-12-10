defmodule Dx.Defd.Kernel do
  @moduledoc false

  use Dx.Defd_

  @moduledx_ args: %{all: :preload_scope}

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

  defd_ is_function(%Dx.Defd.Fn{}) do
    true
  end

  defd_ is_function(term) do
    :erlang.is_function(term)
  end

  defd_ is_function(term, arity) do
    :erlang.is_function(term, arity)
  end
end
