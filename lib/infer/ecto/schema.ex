defmodule Infer.Ecto.Schema do
  @moduledoc "See `Infer`."

  defmacro __using__(use_opts) do
    quote do
      @before_compile unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :infer_directives, accumulate: true)
      Module.register_attribute(__MODULE__, :infer_aliases, accumulate: true)

      import unquote(__MODULE__)

      def infer_preload(record, preloads, opts \\ []) do
        repo = unquote(use_opts) |> Keyword.get(:repo)
        repo.preload(record, preloads, opts)
      end

      def infer_base_type() do
        unquote(use_opts) |> Keyword.get(:for, __MODULE__)
      end
    end
  end

  defmacro __before_compile__(%{module: mod}) do
    directives =
      mod
      |> Module.get_attribute(:infer_directives)
      |> Enum.reverse()
      |> Enum.map(&Macro.escape/1)

    aliases =
      mod
      |> Module.get_attribute(:infer_aliases)
      |> Enum.reverse()
      |> Enum.map(&Macro.escape/1)

    quote do
      def infer_aliases do
        unquote(aliases) |> Infer.Parser.normalize_aliases()
      end

      def infer_rules do
        aliases = infer_aliases()
        type = infer_base_type()

        unquote(directives)
        |> Enum.flat_map(&Infer.Parser.directive_to_rules(&1, type, aliases))
      end
    end
  end

  # Adopt implementation from:
  # - https://hexdocs.pm/absinthe/Absinthe.Schema.Notation.html?#object/3
  # - https://hexdocs.pm/vapor/Vapor.Planner.html#config/2
  defmacro infer(then, opts) do
    quote do
      @infer_directives {:infer, unquote(then), unquote(opts)}
    end
  end

  defmacro infer(opts) do
    quote do
      @infer_directives {:infer, unquote(opts)}
    end
  end

  defmacro predicate_group(opts) do
    quote do
      @infer_aliases unquote(opts)
    end
  end

  @doc "Alias for `predicate_group/1`."
  defmacro field_group(opts) do
    quote do
      @infer_aliases unquote(opts)
    end
  end

  # Adopt implementation from:
  # https://hexdocs.pm/absinthe/Absinthe.Schema.Notation.html?#import_types/2
  #   -> example: https://hexdocs.pm/absinthe/importing-types.html#example
  defmacro import_rules(mod, opts \\ []) do
    quote do
      @infer_directives {:import, unquote(mod), unquote(opts)}
    end
  end
end
