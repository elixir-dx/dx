defmodule Infer.Result do
  @moduledoc """
  Result types and helpers to work with them.

  A result is either:

    - `{:error, e}` if an error occurred
    - `{:not_loaded, data_reqs}` if the result could not be determined without loading more data
    - `{:ok, boolean, binds}` otherwise, in contexts where a boolean is expected (type `t:b()`)
    - `{:ok, result, binds}` otherwise, where `result` can be any value (type `t:v()`)

  ## Data loading

  In general, `{:not_loaded, all_reqs}` only ever returns data requirements that are really needed.

  ### Example using `all`

  For example, using `all?/1` with 3 conditions A, B and C, where

      iex> [
      ...>   {:ok, true, %{}},   # A
      ...>   {:not_loaded, [1]}, # B
      ...>   {:ok, false, %{}},  # C
      ...> ]
      ...> |> Infer.Result.all?()
      {:ok, false, %{}}

  The overall result is `{:ok, false, %{}}`.
  While B would need more data to be loaded, C can already determind and is `false`,
  so and any additional data loaded will not change that.

  ### Example using `find`

  Another example, using `find/1` with 5 conditions A, B, C, D and E, where

      iex> [
      ...>   {:ok, false, %{}},  # A
      ...>   {:not_loaded, [1]}, # B
      ...>   {:not_loaded, [2]}, # C
      ...>   {:ok, true, %{}},   # D
      ...>   {:not_loaded, [3]}, # E
      ...> ]
      ...> |> Infer.Result.find()
      {:not_loaded, [1, 2]}

  The overall result is `{:not_loaded, data_reqs1 + data_reqs2}`.
  While D can already be determined and is `{:ok, true, %{}}`, B and C come first and need more data
  to be loaded, so they can be determined and returned if either is `{:ok, true, %{}}` first.
  All data requirements that might be needed are returned together in the result (those of B and C),
  while those of E can be ruled out, as D already returns `{:ok, true, %{}}` and comes first.
  """

  alias Infer.Util

  @typedoc """
  Possible return values from resolving predicates.
  """
  @type v() :: {:ok, any(), binds()} | {:not_loaded, any()} | {:error, any()}

  @typedoc """
  Possible return values from conditions.
  """
  @type b() :: {:ok, boolean(), binds()} | {:not_loaded, any()} | {:error, any()}

  @type binds() :: %{atom() => any()}

  # Shorthand to conveniently declare optional functions as `fun \\ &identity/1`.
  defp identity(term), do: term

  @doc """
  Wraps a value in an `:ok` result.
  """
  def ok(value, binds \\ %{}), do: {:ok, value, binds}

  @doc """
  If ok, binds the result to the given key and returns the updated tuple.
  Otherwise, returns first argument as is.
  """
  def bind({:ok, result, binds}, key, val), do: {:ok, result, Map.put(binds, key, val)}
  def bind(other, _key, _val), do: other

  @doc """
  When given `{:ok, value, binds}`, runs `fun` on `value` and returns the result.
  Otherwise, returns first argument as is.
  """
  def then({:ok, result, binds}, fun) do
    case fun.(result) do
      {:ok, result, new_binds} -> {:ok, result, Map.merge(new_binds, binds)}
      other -> other
    end
  end

  def then(other, _fun), do: other

  @doc """
  When given `{:ok, value, binds}`, runs `fun` on `value` and returns `{:ok, new_value, binds}`.
  Otherwise, returns first argument as is.
  """
  def transform({:ok, result, binds}, fun), do: {:ok, fun.(result), binds}
  def transform(other, _fun), do: other

  @doc """
  Converts the internal 3-tuple result format (type `t:v()` or `t:b()`) to a 2-tuple format.

  ## Examples

      iex> {:ok, 5, %{}}
      ...> |>Infer.Result.to_simple()
      {:ok, 5}

      iex> {:error, :err}
      ...> |>Infer.Result.to_simple()
      {:error, :err}
  """
  def to_simple({:ok, result, _binds}), do: {:ok, result}
  def to_simple(other), do: other

  @doc """
  Converts 2-tuples to the internal 3-tuple result format (type `t:v()` or `t:b()`).

  ## Examples

      iex> {:ok, 5}
      ...> |>Infer.Result.from_simple()
      {:ok, 5, %{}}

      iex> {:error, :err}
      ...> |>Infer.Result.from_simple()
      {:error, :err}
  """
  def from_simple({:ok, result}), do: ok(result)
  def from_simple(other), do: other

  @doc """
  When given `{:ok, value, binds}` or `{:ok, value}`, returns `value`.
  Otherwise, raises an exception.
  """
  def unwrap!({:ok, result}), do: result
  def unwrap!({:ok, result, _binds}), do: result
  def unwrap!({:not_loaded, _data_reqs}), do: raise(Infer.Error.NotLoaded)
  def unwrap!({:error, e}), do: raise(e)

  @doc """
  Returns `{:ok, true}` if `fun` evaluates to `{:ok, true}` for all elements in `enum`.
  Otherwise, returns `{:not_loaded, data_reqs}` if any yield that.
  Otherwise, returns `{:ok, false}`.

  ## Examples

      iex> [
      ...>   {:ok, true, %{}},
      ...>   {:not_loaded, []},
      ...>   {:ok, false, %{}},
      ...> ]
      ...> |> Infer.Result.all?()
      {:ok, false, %{}}

      iex> [
      ...>   {:ok, true, %{}},
      ...>   {:not_loaded, []},
      ...>   {:ok, true, %{}},
      ...> ]
      ...> |> Infer.Result.all?()
      {:not_loaded, []}

      iex> [
      ...>   {:ok, true, %{}},
      ...>   {:ok, true, %{}},
      ...> ]
      ...> |> Infer.Result.all?()
      {:ok, true, %{}}
  """
  @spec all?(Enum.t(), (any() -> b())) :: b()
  def all?(enum, mapper \\ &identity/1) do
    Enum.reduce_while(enum, ok(true), fn elem, acc ->
      combine(acc, mapper.(elem), :all?)
    end)
  end

  @doc """
  Returns `{:ok, true, binds}` if `fun` evaluates to `{:ok, true, binds}` for any element in `enum`.
  Otherwise, returns `{:not_loaded, data_reqs}` if any yields that.
  Otherwise, returns `{:ok, false, %{}}`.

  ## Examples

      iex> [
      ...>   {:ok, true, %{a: 1}},
      ...>   {:not_loaded, []},
      ...>   {:ok, false, %{}},
      ...> ]
      ...> |> Infer.Result.any?()
      {:ok, true, %{a: 1}}

      iex> [
      ...>   {:ok, false, %{}},
      ...>   {:not_loaded, []},
      ...>   {:ok, false, %{}},
      ...> ]
      ...> |> Infer.Result.any?()
      {:not_loaded, []}

      iex> [
      ...>   {:ok, false, %{}},
      ...>   {:ok, false, %{}},
      ...> ]
      ...> |> Infer.Result.any?()
      {:ok, false, %{}}
  """
  @spec any?(Enum.t(), (any() -> b())) :: b()
  def any?(enum, mapper \\ &identity/1) do
    Enum.reduce_while(enum, ok(false), fn elem, acc ->
      combine(acc, mapper.(elem), :any?)
    end)
  end

  @doc """
  Returns `{:ok, elem}` for the first `elem` for which `fun` evaluates to `{:ok, true}`.
  If any elements before that return `{:not_loaded, data_reqs}`, returns all of them combined as `{:not_loaded, ...}`.
  Otherwise, returns `{:ok, default}`.

  ## Examples

      iex> [
      ...>   {:ok, true, %{}},
      ...>   {:not_loaded, []},
      ...>   {:ok, false, %{}},
      ...> ]
      ...> |> Infer.Result.find()
      {:ok, {:ok, true, %{}}, %{}}

      iex> [
      ...>   {:ok, false, %{}},
      ...>   {:not_loaded, [1]},
      ...>   {:not_loaded, [2]},
      ...>   {:ok, true, %{}},
      ...>   {:not_loaded, [3]},
      ...> ]
      ...> |> Infer.Result.find()
      {:not_loaded, [1, 2]}

      iex> [
      ...>   {:ok, false, %{}},
      ...>   {:ok, false, %{}},
      ...> ]
      ...> |> Infer.Result.find()
      {:ok, nil, %{}}

      iex> [
      ...>   false,
      ...>   false,
      ...> ]
      ...> |> Infer.Result.find(&{:ok, not &1, %{}})
      {:ok, false, %{}}
  """
  @spec find(Enum.t(), (any() -> b()), (any() -> any()), any()) :: v()
  def find(enum, fun \\ &identity/1, result_mapper \\ &ok/2, default \\ ok(nil)) do
    Enum.reduce_while(enum, ok(false), fn elem, acc ->
      combine(acc, fun.(elem), :find)
      |> case do
        {:halt, {:ok, true, binds}} -> {:halt, {:result, elem, binds}}
        other -> other
      end
    end)
    |> case do
      {:result, elem, binds} -> result_mapper.(elem, binds)
      {:ok, false, _binds} -> default
      other -> other
    end
  end

  @doc """
  Returns `{:ok, mapped_results, binds}` if all elements map to `{:ok, result, binds}`.
  Otherwise, returns `{:error, e}` on error, or `{:not_loaded, data_reqs}` with all data requirements.

  ## Examples

      iex> [
      ...>   {:ok, 1, %{}},
      ...>   {:ok, 2, %{}},
      ...>   {:ok, 3, %{}},
      ...> ]
      ...> |> Infer.Result.map()
      {:ok, [1, 2, 3], %{}}

      iex> [
      ...>   {:ok, 1, %{}},
      ...>   {:not_loaded, [:x]},
      ...>   {:ok, 3, %{}},
      ...>   {:not_loaded, [:y]},
      ...> ]
      ...> |> Infer.Result.map()
      {:not_loaded, [:x, :y]}

      iex> [
      ...>   {:ok, 1, %{}},
      ...>   {:error, :x},
      ...>   {:ok, 3, %{}},
      ...>   {:not_loaded, [:y]},
      ...> ]
      ...> |> Infer.Result.map()
      {:error, :x}
  """
  @spec map(Enum.t(), (any() -> v())) :: v()
  def map(enum, mapper \\ &identity/1) do
    Enum.reduce_while(enum, ok([]), fn elem, acc ->
      combine(acc, mapper.(elem), :all)
    end)
    |> transform(&Enum.reverse/1)
  end

  @doc """
  Returns `{:ok, new_map, binds}` with new values if all values map to `{:ok, new_value, binds}`.
  Otherwise, returns `{:error, e}` on error, or `{:not_loaded, data_reqs}` with all data requirements.

  ## Examples

      iex> %{
      ...>   a: {:ok, 1, %{}},
      ...>   b: {:ok, 2, %{}},
      ...>   c: {:ok, 3, %{}},
      ...> }
      ...> |> Infer.Result.map_values()
      {:ok, %{a: 1, b: 2, c: 3}, %{}}

      iex> %{
      ...>   a: {:ok, 1, %{}},
      ...>   b: {:not_loaded, MapSet.new([:x])},
      ...>   c: {:ok, 3, %{}},
      ...>   d: {:not_loaded, MapSet.new([:y])},
      ...> }
      ...> |> Infer.Result.map_values()
      {:not_loaded, MapSet.new([:x, :y])}

      iex> %{
      ...>   a: {:ok, 1, %{}},
      ...>   b: {:error, :x},
      ...>   c: {:ok, 3, %{}},
      ...>   d: {:not_loaded, [:y]},
      ...> }
      ...> |> Infer.Result.map_values()
      {:error, :x}
  """
  def map_values(enum, mapper \\ &identity/1) do
    Enum.reduce_while(enum, ok([]), fn {key, elem}, acc ->
      combine(acc, mapper.(elem) |> transform(&{key, &1}), :all)
    end)
    |> transform(&Map.new/1)
  end

  # The convenience functions `all?/2`, `any?/2`, `find/2`, and `map/2` use this under the hood.
  #
  # Passed to `Enum.reduce_while/3` to combine 2 results on each call.
  #
  # Third arg can be either
  #   - `:any?` (logical `OR`)
  #   - `:all?` (logical `AND`)
  #   - `:find` to return `{:ok, result}` on first match
  #   - `:all` to return all `{:ok, result}` combined as `{:ok, [result1, result2, ...]}`

  @spec combine(b(), b(), :any? | :all?) :: {:cont | :halt, b()}
  @spec combine(b(), b(), :find) :: {:cont | :halt, v()}
  @spec combine(v(), v(), :all) :: {:cont | :halt, v()}

  defp combine(_acc, {:error, e}, _), do: {:halt, {:error, e}}

  defp combine({:not_loaded, r1}, {:not_loaded, r2}, _),
    do: {:cont, {:not_loaded, Util.deep_merge(r1, r2)}}

  defp combine(_acc, {:not_loaded, reqs}, _), do: {:cont, {:not_loaded, reqs}}

  # :find
  defp combine({:not_loaded, reqs}, {:ok, true, _}, :find), do: {:halt, {:not_loaded, reqs}}
  defp combine({:not_loaded, reqs}, {:ok, false, _}, :find), do: {:cont, {:not_loaded, reqs}}
  defp combine({:ok, false, _}, {:ok, true, binds}, :find), do: {:halt, {:ok, true, binds}}
  defp combine(acc, {:ok, false, _}, :find), do: {:cont, acc}

  # :all
  defp combine({:not_loaded, reqs}, {:ok, _, _}, :all), do: {:cont, {:not_loaded, reqs}}

  defp combine({:ok, results, binds}, {:ok, result, new_binds}, :all),
    do: {:cont, {:ok, [result | results], Map.merge(new_binds, binds)}}

  # :any?
  defp combine(_acc, {:ok, true, binds}, :any?), do: {:halt, {:ok, true, binds}}
  defp combine(acc, {:ok, false, _}, :any?), do: {:cont, acc}

  # :all?
  defp combine(_acc, {:ok, false, _}, :all?), do: {:halt, {:ok, false, %{}}}
  defp combine({:not_loaded, reqs}, {:ok, true, _binds}, :all?), do: {:cont, {:not_loaded, reqs}}

  defp combine({:ok, true, binds}, {:ok, true, new_binds}, :all?),
    do: {:cont, {:ok, true, Map.merge(new_binds, binds)}}
end
