defmodule Infer.Rule do
  @moduledoc """
  Represents a rule to apply to an Infer, based on an individual record.

  ## `when`
  Nested map with data requirements and matching values.

  Lists mean one of the values must match.

  Negations can be expressed using `{:not, value}` or `{:not, [values]}`.
  """
  use TypedStruct

  typedstruct do
    field(:type, module() | nil)
    field(:when, map(), default: %{})
    field(:key, atom())
    field(:val, term())
  end
end
