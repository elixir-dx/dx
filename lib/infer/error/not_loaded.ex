defmodule Infer.Error.NotLoaded do
  defexception [:type, :field, :cardinality, :condition]

  def message(error) do
    "Association #{inspect(error.field)} is not loaded " <>
      "on #{inspect(error.type)}. Cannot compare to: " <>
      inspect(error.condition)
  end
end
