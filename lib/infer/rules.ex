defmodule Infer.Rules do
  @moduledoc "See `Infer`."

  defmacro __using__(use_opts) do
    quote do
      if base_type = unquote(use_opts[:for]) do
        @infer_base_type base_type
      end

      @before_compile unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :infer_directives, accumulate: true)
      Module.register_attribute(__MODULE__, :infer_aliases, accumulate: true)

      import unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(%{module: mod}) do
    base_type = Module.get_attribute(mod, :infer_base_type, mod)

    aliases =
      mod
      |> Module.get_attribute(:infer_aliases)
      |> Enum.reverse()
      |> Infer.Parser.normalize_aliases()

    token = %Infer.Parser.Token{type: base_type, aliases: aliases}

    rules =
      mod
      |> Module.get_attribute(:infer_directives)
      |> Enum.reverse()
      |> Infer.Parser.parse(token)

    quote do
      def infer_base_type() do
        unquote(Macro.escape(base_type))
      end

      def infer_aliases do
        unquote(Macro.escape(aliases))
      end

      def infer_rules do
        unquote(Macro.escape(rules))
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

  defmacro infer_alias(opts) do
    quote do
      @infer_directives {:infer_alias, unquote(opts)}
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
