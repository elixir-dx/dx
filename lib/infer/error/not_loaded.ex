defmodule Infer.Error.NotLoaded do
  defexception [:type, :field, :cardinality, :condition, :path]

  def message(error) do
    "Association #{inspect(error.field)} is not loaded " <>
      "on #{inspect(error.type)}." <>
      if error.condition,
        do: " Cannot compare to: " <> inspect(error.condition),
        else: " Cannot get path: " <> inspect(error.path)
  end
end
