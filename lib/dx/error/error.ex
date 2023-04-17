defmodule Dx.Error do
  defexception [:cause]

  def message(error) do
    "Error occurred: #{inspect(error.cause)}"
  end
end
