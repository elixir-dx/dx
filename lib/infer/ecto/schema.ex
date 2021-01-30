defmodule Infer.Ecto.Schema do
  @moduledoc "See `Infer`."

  defmacro __using__(_opts) do
    quote do
      @before_compile unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :infer_directives, accumulate: true)

      import unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(%{module: mod}) do
    directives = Module.get_attribute(mod, :infer_directives)

    directives =
      directives
      |> Enum.reverse()
      |> Enum.map(&Macro.escape/1)

    quote do
      def infer_rules do
        unquote(directives)
        |> Enum.flat_map(&Infer.Engine.directive_to_rules/1)
      end
    end
  end

  # Adopt implementation from:
  # - https://hexdocs.pm/absinthe/Absinthe.Schema.Notation.html?#object/3
  # - https://hexdocs.pm/vapor/Vapor.Planner.html#config/2
  defmacro infer(then, opts) do
    quote do
      @infer_directives unquote({then, opts})
    end
  end

  defmacro infer(opts) do
    quote do
      @infer_directives unquote(opts)
    end
  end

  defmacro predicate_group(_opts) do
    quote do
    end
  end

  @doc "Alias for `predicate_group/1`."
  defmacro field_group(_opts) do
    quote do
    end
  end

  # Adopt implementation from:
  # https://hexdocs.pm/absinthe/Absinthe.Schema.Notation.html?#import_types/2
  #   -> example: https://hexdocs.pm/absinthe/importing-types.html#example
  defmacro import_rules(_mod) do
    quote do
    end
  end
end
