defmodule Infer.DSL do
  @type path :: atom | list(atom)

  defmodule Add do
    @moduledoc """
    """
    use TypedStruct

    typedstruct do
      field(:base, term, enforce: true)
      field(:increment, default: 1)
    end
  end

  defmodule Bind do
    @moduledoc """
    """
    use TypedStruct

    typedstruct do
      field(:as, atom, enforce: true)
      field(:when, default: %{})
    end

    def as(name, condition \\ %{}) do
      %__MODULE__{as: name, when: condition}
    end
  end

  defmodule BindAll do
    @moduledoc """
    """
    use TypedStruct

    typedstruct do
      field(:as, atom, enforce: true)
      field(:when, default: %{})
    end

    def as(name, condition \\ %{}) do
      %__MODULE__{as: name, when: condition}
    end
  end

  defmodule Bound do
    @moduledoc """
    Represents a reference to a variable bound using `Bind` or `BindAll`.
    Instead of an `Atom` or `String` to reference the bound value as a whole,
    a `List` can be passed to get a nested value at the given path inside the bound variable.
    """
    use TypedStruct

    typedstruct do
      field(:at, Infer.DSL.path(), enforce: true)
    end
  end

  defmodule Count do
    @moduledoc """
    """
    use TypedStruct

    typedstruct do
      field(:of, term, enforce: true)
    end
  end

  defmodule Iterator do
    @moduledoc """
    Represents an iterator inside a loop, e.g. `MapWhile`.
    """
    use TypedStruct

    typedstruct do
    end
  end

  defmodule MapWhile do
    use TypedStruct

    typedstruct do
      field(:over, Enumerable.t(), enforce: true)
      field(:when, map(), default: %{})
      field(:then, term(), enforce: true)
    end
  end

  defmodule QueryAll do
    use TypedStruct

    typedstruct do
      field(:type, module(), enforce: true)
      field(:where, map(), default: %{})
      field(:order_by, atom() | keyword(), default: [])
    end
  end

  defmodule Range do
    use TypedStruct

    typedstruct do
      field(:from, term, enforce: true)
      field(:to, term, enforce: true)
    end
  end

  defmodule Ref do
    @moduledoc """
    Represents a reference to another field.
    `:path` is always traversed from the root, i.e. the type where the rule is defined.
    An `Atom` or `String` instead of a `List` is treated as if it was a list with one element.
    En empty list `[]` references the subject itself, as a whole.
    """
    use TypedStruct

    typedstruct do
      field(:to, Infer.DSL.path(), enforce: true)
    end

    def to(path) do
      %__MODULE__{to: path}
    end
  end

  def add(base, increment \\ 1), do: %Add{base: base, increment: increment}
  def bind(condition, as: name), do: %Bind{as: name, when: condition}
  def bind(name, condition), do: %Bind{as: name, when: condition}
  def bind_all(name, condition), do: %Bind{as: name, when: condition}
  def bound(path), do: %Bound{at: path}
  def count(of), do: %Count{of: of}
  def iterator(), do: %Iterator{}
  def range(from, to), do: %Range{from: from, to: to}
  def ref(path), do: %Ref{to: path}
end
