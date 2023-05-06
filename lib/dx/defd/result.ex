defmodule Dx.Defd.Result do
  # Shorthand to conveniently declare optional functions as `fun \\ &identity/1`.
  defp identity(term), do: term

  @doc """
  Wraps a value in an `:ok` result.
  """
  def ok(value), do: {:ok, value}

  @doc """
  When given `{:ok, value}`, runs `fun` on `value` and returns the result.
  Otherwise, returns first argument as is.
  """
  def then({:ok, result}, fun) do
    case fun.(result) do
      {:ok, result} -> {:ok, result}
      other -> other
    end
  end

  def then(other, _fun), do: other

  @doc """
  When given `{:ok, value}`, runs `fun` on `value` and returns `{:ok, new_value}`.
  Otherwise, returns first argument as is.
  """
  def transform({:ok, result}, fun), do: {:ok, fun.(result)}
  def transform(other, _fun), do: other

  @doc """
  Returns `{:ok, mapped_results}` if all elements map to `{:ok, result}`.
  Otherwise, returns `{:error, e}` on error, or `{:not_loaded, data_reqs}` with all data requirements.

  ## Examples

      iex> [
      ...>   {:ok, 1},
      ...>   {:ok, 2},
      ...>   {:ok, 3},
      ...> ]
      ...> |> Dx.Defd.Result.map()
      {:ok, [1, 2, 3]}

      iex> [
      ...>   {:ok, 1},
      ...>   {:not_loaded, [:x]},
      ...>   {:ok, 3},
      ...>   {:not_loaded, [:y]},
      ...> ]
      ...> |> Dx.Defd.Result.map()
      {:not_loaded, [:x, :y]}

      iex> [
      ...>   {:ok, 1},
      ...>   {:error, :x},
      ...>   {:ok, 3},
      ...>   {:not_loaded, [:y]},
      ...> ]
      ...> |> Dx.Defd.Result.map()
      {:error, :x}
  """
  def map(enum, mapper \\ &identity/1) do
    Enum.reduce_while(enum, ok([]), fn elem, acc ->
      combine(:all, acc, mapper.(elem))
    end)
    |> transform(&Enum.reverse/1)
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
      ...> |> Dx.Defd.Result.collect_reverse()
      {:ok, [3, 2, 1]}

      iex> [
      ...>   {:ok, 1},
      ...>   {:not_loaded, [:x]},
      ...>   {:ok, 3},
      ...>   {:not_loaded, [:y]},
      ...> ]
      ...> |> Dx.Defd.Result.collect_reverse()
      {:not_loaded, [:y, :x]}

      iex> [
      ...>   {:ok, 1},
      ...>   {:error, :x},
      ...>   {:ok, 3},
      ...>   {:not_loaded, [:y]},
      ...> ]
      ...> |> Dx.Defd.Result.collect_reverse()
      {:error, :x}
  """
  def collect_reverse(list, acc \\ {:ok, []})

  def collect_reverse([], acc) do
    acc
  end

  def collect_reverse([{:error, e} | _tail], _acc) do
    {:error, e}
  end

  def collect_reverse([{:not_loaded, r1} | tail], {:not_loaded, r2}) do
    acc = {:not_loaded, Dx.Util.deep_merge(r1, r2)}
    collect_reverse(tail, acc)
  end

  def collect_reverse([{:not_loaded, _reqs} = reqs | tail], _acc) do
    collect_reverse(tail, reqs)
  end

  def collect_reverse([{:ok, result} | tail], {:ok, results}) do
    acc = {:ok, [result | results]}
    collect_reverse(tail, acc)
  end

  def collect_reverse([{:ok, _result} | tail], acc) do
    collect_reverse(tail, acc)
  end

  defp combine(mode, acc, elem, extra \\ nil)

  defp combine(_mode, _acc, {:error, e}, _), do: {:halt, {:error, e}}

  defp combine(_mode, {:not_loaded, r1}, {:not_loaded, r2}, _),
    do: {:cont, {:not_loaded, Dx.Util.deep_merge(r1, r2)}}

  defp combine(_mode, _acc, {:not_loaded, reqs}, _), do: {:cont, {:not_loaded, reqs}}

  # :all
  defp combine(:all, {:not_loaded, reqs}, {:ok, _}, _), do: {:cont, {:not_loaded, reqs}}

  defp combine(:all, {:ok, results}, {:ok, result}, _),
    do: {:cont, {:ok, [result | results]}}
end
