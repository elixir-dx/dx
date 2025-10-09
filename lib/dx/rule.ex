defmodule Dx.Rule do
  # Represents a rule, based on an individual record.
  #
  # ## `when`
  # Nested map with data requirements and matching values.
  #
  # Lists mean one of the values must match.
  #
  # Negations can be expressed using `{:not, value}` or `{:not, [values]}`.

  @moduledoc false

  defstruct [:type, :key, :val, when: %{}]

  @type t() :: %__MODULE__{
          type: module() | nil,
          when: map(),
          key: atom(),
          val: term()
        }
end
