defmodule Dx.Test.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Dx.Test.Repo
      alias Dx.Test.Schema.{List, ListCalendarOverride, ListTemplate, Role, Task, User}

      import Test.Support.Factories
      import Test.Support.DateTimeHelpers
      import Dx.Test.DataCase.Helpers
    end
  end

  defmodule Helpers do
    def unload(record) when is_struct(record) do
      Dx.Test.Repo.reload!(record)
    end

    def unload(map) when is_map(map) do
      Map.new(map, fn {k, v} -> {unload(k), unload(v)} end)
    end

    def unload(records) when is_list(records) do
      Enum.map(records, &unload/1)
    end

    def unload(tuple) when is_tuple(tuple) do
      tuple |> Tuple.to_list() |> unload() |> List.to_tuple()
    end

    def unload(other), do: other

    def assert_queries(expected_query_parts, fun) do
      test_process = self()
      handler_id = "ecto-queries-test"

      callback = fn
        _event, _measurements, %{result: {:ok, %{command: :select}}} = metadata, _config ->
          send(
            test_process,
            {:ecto_query, Dx.Ecto.Query.replace_params(metadata.query, metadata.params)}
          )

        _, _, _, _ ->
          nil
      end

      :ok = :telemetry.attach(handler_id, [:dx, :test, :repo, :query], callback, nil)
      fun.()
      :telemetry.detach(handler_id)

      queries = receive_queries()

      {_matched, unmatched, remaining} =
        Enum.reduce(queries, {[], [], expected_query_parts}, &query_matches_any?/2)

      assert unmatched == []
      assert remaining == []
    end

    defp receive_queries(timeout \\ 0, acc \\ []) do
      receive do
        {:ecto_query, msg} -> receive_queries(timeout, [msg | acc])
      after
        timeout -> :lists.reverse(acc)
      end
    end

    defp query_matches_any?(query, {matched, unmatched, remaining}) do
      Enum.split_with(remaining, &query_matches?(query, &1))
      |> case do
        {[_match | match_rest], rest} -> {[query | matched], unmatched, match_rest ++ rest}
        {_, rest} -> {matched, [query | unmatched], rest}
      end
    end

    defp query_matches?(query, multiple) when is_list(multiple),
      do: Enum.all?(multiple, &query_matches?(query, &1))

    defp query_matches?(query, part) when is_binary(part), do: query =~ part
    defp query_matches?(query, %Regex{} = regex), do: String.match?(query, regex)
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Dx.Test.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Dx.Test.Repo, {:shared, self()})
    end

    :ok
  end
end
