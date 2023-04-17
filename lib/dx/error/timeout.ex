defmodule Dx.Error.Timeout do
  defexception []

  def message(_error) do
    "Timeout occurred"
  end
end
