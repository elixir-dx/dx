defmodule Dx.Defd.Fn do
  @moduledoc false

  defstruct [:ok?, :final_args_ok?, :fun, :ok_fun, :final_args_fun, :final_args_ok_fun, :scope]

  def maybe_unwrap(%__MODULE__{fun: fun}), do: fun
  def maybe_unwrap(other), do: other

  def maybe_unwrap_ok(%__MODULE__{ok_fun: fun}), do: fun
  def maybe_unwrap_ok(other), do: other

  def maybe_unwrap_final_args_ok(%__MODULE__{final_args_ok_fun: fun}), do: fun
  def maybe_unwrap_final_args_ok(other), do: other

  def to_defd_fun(%__MODULE__{fun: fun}), do: fun
  def to_defd_fun(fun) when is_function(fun), do: wrap_defd_fun(fun)
  def to_defd_fun(other), do: other

  wrap_defd_args = Macro.generate_arguments(12, __MODULE__)

  for arity <- 0..12, args = Enum.take(wrap_defd_args, arity) do
    defp wrap_defd_fun(fun) when is_function(fun, unquote(arity)) do
      fn unquote_splicing(args) ->
        {:ok, fun.(unquote_splicing(args))}
      end
    end
  end
end
