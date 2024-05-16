defmodule Dx.Ecto.Query.Batches do
  @moduledoc """
  Determines which field to batch queries by.

  ## Problem

  We have data requirements that need to be fulfilled by
  executing queries.

  Each data requirement consists of a group, for example
  a set of fixed options for running a query, and a list
  of filters, each filter being a field + value to match on.

  Each query can only have one field to be batched on,
  i.e. one field takes a list of values to fulfill
  multiple data requirements.

  The goal is to minimize the number of queries.
  This is trivial when filtering by 0 or 1 fields.
  When filtering by 2 or more fields, some work must be
  done to determine the ideal field to batch by.

  ## Approach

  We basically count the filter combinations for each
  potential field to batch on.
  Each combination consists of the field to batch on + all
  other filters as a fixed set.

  ## Examples

      iex> add_filters(:query1, [color: "red", char: "A"])
      ...> |> get_batches()
      [
        query1: [
          {:char, ["A"], color: "red"}
        ]
      ]

      iex> add_filters(:query1, [color: "red", char: "A"])
      ...> |> add_filters(:query1, [color: "blue", char: "A"])
      ...> |> get_batches()
      [
        query1: [
          {:color, ["blue", "red"], char: "A"}
        ]
      ]

      iex> add_filters(:query1, [color: "red", char: "A", size: "L"])
      ...> |> add_filters(:query1, [color: "blue", size: "S", char: "A"])
      ...> |> add_filters(:query1, [color: "pink", size: "S", char: "B"])
      ...> |> add_filters(:query1, [color: "pink", size: "S", char: "A"])
      ...> |> get_batches()
      [
        query1: [
          {:char, ["A"], color: "blue", size: "S"},
          {:char, ["A", "B"], color: "pink", size: "S"},
          {:char, ["A"], color: "red", size: "L"}
        ]
      ]

      iex> add_filters(:query1, [color: "red"])
      ...> |> add_filters(:query1, [color: "blue"])
      ...> |> get_batches()
      [
        query1: [
          {:color, ["blue", "red"], []}
        ]
      ]

      iex> add_filters(:query1, [])
      ...> |> get_batches()
      [
        query1: [
          {}
        ]
      ]
  """

  @doc "Initializes a new state to call other functions on"
  def new(), do: %{}

  @doc """
  Adds one data requirement, consisting of a group + list of filters,
  to a given (or newly initialized) state
  """
  def add_filters(state \\ %{}, group, filters)

  def add_filters(state, group, []),
    do: map_put_in(state, [group], [])

  def add_filters(state, group, filters) when is_map(filters),
    do: add_filters(state, group, Enum.sort(filters))

  def add_filters(state, group, [{key, value}]),
    do: map_put_in(state, [group, key, [], value], true)

  def add_filters(state, group, filters) do
    add_combinations(state, group, Enum.sort(filters), [])
  end

  defp add_combinations(state, _group, [], _prev), do: state

  defp add_combinations(state, group, [{key, value} = filter | next], prev) do
    other_filters = :lists.reverse(prev, next)

    state
    |> map_put_in([group, key, other_filters, value], true)
    |> add_combinations(group, next, [filter | prev])
  end

  def map_put_in(_map, [], value), do: value

  def map_put_in(map, [key | path], value) do
    submap = map |> Map.get(key, %{}) |> map_put_in(path, value)
    Map.put(map, key, submap)
  end

  @doc """
  Returns an optimal set of batches for the given state returned by the
  other functions.

  ## Format

      [
        group1: [
          {:batch_key, list_of_values, other_filters_keyword},
          # ...
        ],
        # ...
      ]
  """
  def get_batches(state) do
    Enum.map(state, fn
      {group, []} ->
        {group, [{}]}

      {group, fields_and_combinations} ->
        {batch_field, combinations} =
          Enum.min_by(Enum.sort(fields_and_combinations), fn {_field, combinations} ->
            map_size(combinations)
          end)

        batches =
          Enum.map(combinations, fn {other_filters, values_map} ->
            {batch_field, Map.keys(values_map), other_filters}
          end)

        {group, batches}
    end)
  end
end
