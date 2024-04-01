defmodule Dx.Defd.Fn do
  defstruct [:ok?, :fun, :ok_fun, :scope]

  def maybe_unwrap(%__MODULE__{fun: fun}), do: fun
  def maybe_unwrap(other), do: other

  # def maybe_unwrap_ok(%__MODULE__{ok?: false}), do: raise ArgumentError, "This is not ok!"
  def maybe_unwrap_ok(%__MODULE__{ok_fun: fun}), do: dbg(fun)
  def maybe_unwrap_ok(other), do: dbg(other)
end
