defmodule Infer.Ecto.Schema do
  @moduledoc "See `Infer`."

  defmacro __using__(use_opts) do
    quote do
      use Infer.Rules, unquote(use_opts)

      def infer_query_module() do
        Infer.Ecto.Query
      end

      def infer_repo() do
        unquote(use_opts |> Keyword.get(:repo))
      end
    end
  end
end
