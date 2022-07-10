defmodule Dx.Ecto.Schema do
  @moduledoc "See `Dx`."

  defmacro __using__(use_opts) do
    quote do
      use Dx.Rules, unquote(use_opts)

      def dx_query_module() do
        Dx.Ecto.Query
      end

      def dx_repo() do
        unquote(use_opts |> Keyword.get(:repo))
      end
    end
  end
end
