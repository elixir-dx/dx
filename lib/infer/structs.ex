defmodule Infer.Field do
  @moduledoc """
  Represents meta info for a field, e.g. to derive validations, casting rules, or generate forms.

  The type will be read from the Ecto schema of the record given in the `Infer.Context`.
  """

  use TypedStruct

  typedstruct do
    field(:required, boolean(), default: false)
    field(:editable, boolean(), default: true)
    field(:visible, boolean(), default: true)
  end
end

defmodule Infer.Context do
  @moduledoc """
  Represents a complete context around applying a set of `Infer.Rule` declarations to a record.

  When run using `Infer.Runner.run/2`, additional arguments may be passed, which will be
  accessible in the rules via `:args`.
  """

  use TypedStruct

  typedstruct do
    field(:args, map(), default: %{})
    field(:record, struct(), enforce: true)
    field(:fields, %{atom() => Infer.Field.t()}, default: %{})
  end
end

defmodule Infer.Infer do
  @moduledoc """
  Represents an attribute that's inferred from other attributes
  (including nested associations).
  """
  use TypedStruct

  typedstruct do
    field(:when, %{args: map(), record: map()} | nil)
    field(:inputs, list() | map(), default: [])
    field(:result, term(), default: true)
  end
end

defmodule Infer.Rule do
  @moduledoc """
  Represents a rule to apply to an Infer, based on an individual record.

  ## `when`
  Nested map with data requirements and matching values.

  Lists mean one of the values must match.

  Negations can be expressed using `{:not, value}` or `{:not, [values]}`.

  ## `set`
  Nested map with updates to the value and/or meta data (defined in `Infer.Field`)
  of each record field.
  """
  use TypedStruct

  typedstruct do
    field(:type, module() | nil)
    field(:desc, String.t())
    field(:when, map(), default: %{})
    field(:key, atom())
    field(:val, term())
  end
end

defmodule Infer.Helpers do
  @moduledoc "Functions to help reduce repetitiveness when defining Entities."

  def infer(opts) when is_list(opts), do: struct!(Infer.Infer, opts)
  def infer(when_), do: %Infer.Infer{when: when_}
  def infer(when_, opts) when is_list(opts), do: struct!(Infer.Infer, [{:when, when_} | opts])
  def infer(when_, result), do: %Infer.Infer{when: when_, result: result}

  def infer(when_, inputs, result) when is_list(inputs) and is_function(result),
    do: %Infer.Infer{when: when_, inputs: inputs, result: result}
end

defmodule Infer.Runner do
  @moduledoc """
  `run/2` takes a record and optional args and returns a `Infer.Context`.

  The record's schema must have a `rules/0` function defined.
  """

  def run(%_type{} = _record, _args \\ []) do
    # rules = type.rules()
    # context = %Infer.Context{record: record, args: Map.new(args)}
    # Enum.reduce(rules, context, ...)
  end
end
