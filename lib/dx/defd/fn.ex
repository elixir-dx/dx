defmodule Dx.Defd.Fn do
  defstruct [:ok?, :final_args_ok?, :fun, :ok_fun, :final_args_fun, :final_args_ok_fun, :scope]

  def maybe_unwrap(%__MODULE__{fun: fun}), do: fun
  def maybe_unwrap(other), do: other

  # def maybe_unwrap_ok(%__MODULE__{ok?: false}), do: raise ArgumentError, "This is not ok!"
  def maybe_unwrap_ok(%__MODULE__{ok_fun: fun}), do: fun
  def maybe_unwrap_ok(other), do: other

  def maybe_unwrap_final_args_ok(%__MODULE__{final_args_ok_fun: fun}), do: fun
  def maybe_unwrap_final_args_ok(other), do: other
end
