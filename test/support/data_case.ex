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

      alias Dx.Test.Schema.List
      alias Dx.Test.Schema.ListCalendarOverride
      alias Dx.Test.Schema.ListTemplate
      alias Dx.Test.Schema.Role
      alias Dx.Test.Schema.RoleAuditLog
      alias Dx.Test.Schema.Task
      alias Dx.Test.Schema.User

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

      result =
        try do
          fun.()
        after
          :telemetry.detach(handler_id)
          nil
        end

      queries = receive_queries()

      {matched, unmatched, remaining} =
        Enum.reduce(queries, {[], [], expected_query_parts}, &query_matches_any?/2)

      error_message =
        [Unmatched: unmatched, Remaining: remaining, Matched: matched]
        |> Enum.reject(&match?({_label, []}, &1))
        |> Enum.map_join("\n\n", &format_queries/1)

      assert {unmatched, remaining} == {[], []}, error_message

      result
    end

    defp format_queries({label, queries}) do
      """
      #{label} queries:

      #{Enum.map_join(queries, "\n\n", &format_query/1)}
      """
    end

    defp format_query(query_parts) when is_list(query_parts),
      do: Enum.map_join(query_parts, " ... ", &format_query/1)

    defp format_query(query) when is_binary(query), do: query
    defp format_query(query_pattern), do: inspect(query_pattern)

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
