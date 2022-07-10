defmodule Dx.Test.DataLoadingCase do
  @moduledoc """
  This module defines the setup for tests that assert on
  certain Ecto queries being executed (or not).

  All Ecto queries are sent to the test process via a
  message of the form `{:ecto_query, metadata}`.

  Can not be used with `async: true`.
  """

  defmacro __using__(opts) do
    quote do
      use Dx.Test.DataCase, unquote(opts)

      # subscribe to ecto queries
      setup %{async: async} do
        if async,
          do: raise(ArgumentError, "Dx.Test.DataLoadingCase can not be used with async: true")

        test_process = self()
        handler_id = "ecto-queries-test"

        callback = fn
          _event, _measurements, %{result: {:ok, %{command: :select}}} = metadata, _config ->
            send(test_process, {:ecto_query, metadata})

          _, _, _, _ ->
            nil
        end

        :ok = :telemetry.attach(handler_id, [:dx, :test, :repo, :query], callback, nil)

        on_exit(fn ->
          :telemetry.detach(handler_id)
        end)
      end
    end
  end
end
