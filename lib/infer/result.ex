defmodule Infer.Result do
  @moduledoc """
  Result types and helpers to work with them.

  A result is either:

    - `{:error, e}` if an error occurred
    - `{:not_loaded, data_reqs}` if the result could not be determined without loading more data
    - `{:ok, boolean}` otherwise, in contexts where a boolean is expected (type `t:b()`)
    - `{:ok, result}` otherwise, where `result` can be any value (type `t:v()`)

  ## Data loading

  In general, `{:not_loaded, all_reqs}` only ever returns data requirements that are really needed.

  ### Example using `all`

  For example, using `all?/1` with 3 conditions A, B and C, where

      iex> [
      ...>   {:ok, true},        # A
      ...>   {:not_loaded, [1]}, # B
      ...>   {:ok, false},       # C
      ...> ]
      ...> |> Infer.Result.all?()
      {:ok, false}

  The overall result is `{:ok, false}`.
  While B would need more data to be loaded, C can already determind and is `false`,
  so and any additional data loaded will not change that.

  ### Example using `find`

  Another example, using `find/1` with 5 conditions A, B, C, D and E, where

      iex> [
      ...>   {:ok, false},       # A
      ...>   {:not_loaded, [1]}, # B
      ...>   {:not_loaded, [2]}, # C
      ...>   {:ok, true},        # D
      ...>   {:not_loaded, [3]}, # E
      ...> ]
      ...> |> Infer.Result.find()
      {:not_loaded, [1, 2]}

  The overall result is `{:not_loaded, data_reqs1 + data_reqs2}`.
  While D can already be determined and is `{:ok, true}`, B and C come first and need more data
  to be loaded, so they can be determined and returned if either is `{:ok, true}` first.
  All data requirements that might be needed are returned together in the result (those of B and C),
  while those of E can be ruled out, as D already returns `{:ok, true}` and comes first.
  """

  alias Infer.Util

  @typedoc """
  Possible return values from resolving predicates.
  """
  @type v() :: {:ok, any()} | {:not_loaded, any()} | {:error, any()}

  @typedoc """
  Possible return values from conditions.
  """
  @type b() :: {:ok, boolean()} | {:not_loaded, any()} | {:error, any()}

  # Shorthand to conveniently declare optional functions as `fun \\ &identity/1`.
  defp identity(term), do: term

  @doc """
  When given `{:ok, value}`, runs `fun` on `value` and returns the result.
  Otherwise, returns first argument as is.
  """
  def then({:ok, result}, fun), do: fun.(result)
  def then(other, _fun), do: other

  @doc """
  When given `{:ok, value}`, runs `fun` on `value` and returns `{:ok, new_value}`.
  Otherwise, returns first argument as is.
  """
  def transform({:ok, result}, fun), do: {:ok, fun.(result)}
  def transform(other, _fun), do: other

  @doc """
  When given `{:ok, value}`, returns `value`.
  Otherwise, raises an exception.
  """
  def unwrap!({:ok, result}), do: result
  def unwrap!({:not_loaded, _data_reqs}), do: raise(Infer.Error.NotLoaded)
  def unwrap!({:error, e}), do: raise(e)

  @doc """
  Returns `{:ok, true}` if `fun` evaluates to `{:ok, true}` for all elements in `enum`.
  Otherwise, returns `{:not_loaded, data_reqs}` if any yield that.
  Otherwise, returns `{:ok, false}`.

  ## Examples

      iex> [
      ...>   {:ok, true},
      ...>   {:not_loaded, []},
      ...>   {:ok, false},
      ...> ]
      ...> |> Infer.Result.all?()
      {:ok, false}

      iex> [
      ...>   {:ok, true},
      ...>   {:not_loaded, []},
      ...>   {:ok, true},
      ...> ]
      ...> |> Infer.Result.all?()
      {:not_loaded, []}

      iex> [
      ...>   {:ok, true},
      ...>   {:ok, true},
      ...> ]
      ...> |> Infer.Result.all?()
      {:ok, true}
  """
  @spec all?(Enum.t(), (any() -> b())) :: b()
  def all?(enum, mapper \\ &identity/1) do
    Enum.reduce_while(enum, {:ok, true}, fn elem, acc ->
      combine(acc, mapper.(elem), :all?)
    end)
  end

  @doc """
  Returns `{:ok, true}` if `fun` evaluates to `{:ok, true}` for any element in `enum`.
  Otherwise, returns `{:not_loaded, data_reqs}` if any yields that.
  Otherwise, returns `{:ok, false}`.

  ## Examples

      iex> [
      ...>   {:ok, true},
      ...>   {:not_loaded, []},
      ...>   {:ok, false},
      ...> ]
      ...> |> Infer.Result.any?()
      {:ok, true}

      iex> [
      ...>   {:ok, false},
      ...>   {:not_loaded, []},
      ...>   {:ok, false},
      ...> ]
      ...> |> Infer.Result.any?()
      {:not_loaded, []}

      iex> [
      ...>   {:ok, false},
      ...>   {:ok, false},
      ...> ]
      ...> |> Infer.Result.any?()
      {:ok, false}
  """
  @spec any?(Enum.t(), (any() -> b())) :: b()
  def any?(enum, mapper \\ &identity/1) do
    Enum.reduce_while(enum, {:ok, false}, fn elem, acc ->
      combine(acc, mapper.(elem), :any?)
    end)
  end

  @doc """
  Returns `{:ok, elem}` for the first `elem` for which `fun` evaluates to `{:ok, true}`.
  If any elements before that return `{:not_loaded, data_reqs}`, returns all of them combined as `{:not_loaded, ...}`.
  Otherwise, returns `{:ok, default}`.

  ## Examples

      iex> [
      ...>   {:ok, true},
      ...>   {:not_loaded, []},
      ...>   {:ok, false},
      ...> ]
      ...> |> Infer.Result.find()
      {:ok, {:ok, true}}

      iex> [
      ...>   {:ok, false},
      ...>   {:not_loaded, [1]},
      ...>   {:not_loaded, [2]},
      ...>   {:ok, true},
      ...>   {:not_loaded, [3]},
      ...> ]
      ...> |> Infer.Result.find()
      {:not_loaded, [1, 2]}

      iex> [
      ...>   {:ok, false},
      ...>   {:ok, false},
      ...> ]
      ...> |> Infer.Result.find()
      {:ok, nil}

      iex> [
      ...>   false,
      ...>   false,
      ...> ]
      ...> |> Infer.Result.find(&{:ok, not &1})
      {:ok, false}
  """
  @spec find(Enum.t(), (any() -> b()), (any() -> any()), any()) :: v()
  def find(enum, fun \\ &identity/1, result_mapper \\ &identity/1, default \\ {:ok, nil}) do
    Enum.reduce_while(enum, {:ok, false}, fn elem, acc ->
      combine(acc, fun.(elem), :find)
      |> case do
        {:halt, {:ok, true}} -> {:halt, {:result, elem}}
        other -> other
      end
    end)
    |> case do
      {:result, elem} -> {:ok, result_mapper.(elem)}
      {:ok, false} -> default
      other -> other
    end
  end

  @doc """
  Returns `{:ok, mapped_results}` if all elements map to `{:ok, result}`.
  Otherwise, returns `{:error, e}` on error, or `{:not_loaded, data_reqs}` with all data requirements.

  ## Examples

      iex> [
      ...>   {:ok, 1},
      ...>   {:ok, 2},
      ...>   {:ok, 3},
      ...> ]
      ...> |> Infer.Result.map()
      {:ok, [1, 2, 3]}

      iex> [
      ...>   {:ok, 1},
      ...>   {:not_loaded, [:x]},
      ...>   {:ok, 3},
      ...>   {:not_loaded, [:y]},
      ...> ]
      ...> |> Infer.Result.map()
      {:not_loaded, [:x, :y]}

      iex> [
      ...>   {:ok, 1},
      ...>   {:error, :x},
      ...>   {:ok, 3},
      ...>   {:not_loaded, [:y]},
      ...> ]
      ...> |> Infer.Result.map()
      {:error, :x}
  """
  @spec map(Enum.t(), (any() -> v())) :: v()
  def map(enum, mapper \\ &identity/1) do
    Enum.reduce_while(enum, {:ok, []}, fn elem, acc ->
      combine(acc, mapper.(elem), :all)
    end)
    |> transform(&Enum.reverse/1)
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
  defp combine({:not_loaded, reqs}, {:ok, true}, :find), do: {:halt, {:not_loaded, reqs}}
  defp combine({:not_loaded, reqs}, {:ok, false}, :find), do: {:cont, {:not_loaded, reqs}}
  defp combine({:ok, false}, {:ok, true}, :find), do: {:halt, {:ok, true}}
  defp combine(acc, {:ok, false}, :find), do: {:cont, acc}

  # :all
  defp combine({:not_loaded, reqs}, {:ok, _}, :all), do: {:cont, {:not_loaded, reqs}}
  defp combine({:ok, results}, {:ok, result}, :all), do: {:cont, {:ok, [result | results]}}

  # :any?
  defp combine(_acc, {:ok, true}, :any?), do: {:halt, {:ok, true}}
  defp combine(acc, {:ok, false}, :any?), do: {:cont, acc}

  # :all?
  defp combine(_acc, {:ok, false}, :all?), do: {:halt, {:ok, false}}
  defp combine(acc, {:ok, true}, :all?), do: {:cont, acc}
end
