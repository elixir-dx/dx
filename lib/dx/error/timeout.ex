defmodule Dx.Error.Timeout do
  defexception []

  def message(_error) do
    "A timeout occurred while loading the data required."
  end
end
