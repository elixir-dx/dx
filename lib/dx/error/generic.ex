defmodule Dx.Error.Generic do
  defexception [:cause]

  def message(error) do
    "Error occurred: #{inspect(error.cause, pretty: true)}"
  end
end
