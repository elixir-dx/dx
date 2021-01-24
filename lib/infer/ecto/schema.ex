defmodule Infer.Ecto.Schema do
  @moduledoc "See `Infer`."

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
    end
  end

  # Adopt implementation from:
  # - https://hexdocs.pm/absinthe/Absinthe.Schema.Notation.html?#object/3
  # - https://hexdocs.pm/vapor/Vapor.Planner.html#config/2
  defmacro infer(_then, _opts) do
    quote do
    end
  end

  defmacro infer(_opts) do
    quote do
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
