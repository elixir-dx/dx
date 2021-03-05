defmodule Infer.Ecto.Schema do
  @moduledoc "See `Infer`."

  defmacro __using__(use_opts) do
    quote do
      use Infer.Rules, unquote(use_opts)

      def infer_preload(record, preloads, opts \\ []) do
        repo = unquote(use_opts |> Keyword.get(:repo))
        repo.preload(record, preloads, opts)
      end
    end
  end
end
