defmodule Dx.Schema.Type do
  @moduledoc """
  Represents the type of a data structure or literal.

  ## Structure

  _(* = not implemented yet)_

  ### Basic types

  | _Type_     | _Example_ |
  |------------|-----------|
  | `:any`     |           |
  | `:integer` | `7`       |
  | `:float`   | `3.14`    |
  | `:boolean` | `true`    |
  | `:string`  | `"foo"`   |
  | `:atom`    | `:foo`    |
  | `nil`      | `nil`     |

  ### Nested types

  | _Type_                                       | _Example_                       |
  |----------------------------------------------|---------------------------------|
  | `{:array, :integer}`                         | `[1, 2, 3]`                     |
  | `{:tuple, {:atom, :string}}`                 | `{:ok, "foo"}`                  |
  | `{:map, {:atom, :float}}` *                  | `%{foo: 1.1, bar: 2.7}`         |
  | `{:map, {:atom, :float}, %{foo: :string}}` * | `%{foo: "bar", bar: 2.7}`       |
  | `{:map, %{foo: :string}}`                    | `%{foo: "bar"}`                 |
  | `MyApp.Struct`                               | `%MyApp.Struct{foo: 1, bar: 2}` |

  ### Union types

  Represented by a list.

  | _Type_                                     | _Example_                       |
  |--------------------------------------------|---------------------------------|
  | `[:integer, :float, nil]`                  | `1.0`                           |
  | `{:array, [:integer, :float, nil]}`        | `[1.0, nil, 3, 4]`              |

  ### Subset types

  | _Type_                                                     | _Example_                         |
  |------------------------------------------------------------|-----------------------------------|
  | `{:integer, [1, 2, 3]}`                                    | `2`                               |
  | `{:integer, {:gte, 0}}` *                                  | `0`                               |
  | `{:integer, {:all, [{:gte, 0}, {:lt, 7}]}}` *              | `6`                               |
  | `{:struct, MyApp.Struct, [:foo]}` *                        | `%MyApp.Struct{foo: 1}`           |
  | `{:struct, MyApp.Struct, [:foo, :bar], %{bar: :float}}` *  | `%MyApp.Struct{foo: 1, bar: 1.7}` |
  | `{:struct, MyApp.Struct, %{foo: :integer, bar: :float}}` * | `%MyApp.Struct{foo: 1, bar: 1.7}` |

  """

  alias Dx.Util

  @doc """
  ## Examples

      iex> of(87)
      {:integer, 87}

      iex> of(1.2)
      {:float, 1.2}

      iex> of("foo")
      {:string, "foo"}

      iex> of(:foo)
      {:atom, :foo}

      iex> of(false)
      {:boolean, false}

      iex> of(nil)
      nil

      iex> of(%Ecto.Query{})
      Ecto.Query

      iex> of(%{foo: nil, bar: 1})
      {:map, %{foo: nil, bar: {:integer, 1}}}
  """
  def of(integer) when is_integer(integer), do: {:integer, integer}
  def of(float) when is_float(float), do: {:float, float}
  def of(string) when is_binary(string), do: {:string, string}
  def of(boolean) when is_boolean(boolean), do: {:boolean, boolean}
  def of(nil), do: nil
  def of(atom) when is_atom(atom), do: {:atom, atom}
  def of(%type{}), do: type
  def of(function) when is_function(function), do: :any
  def of(map) when is_map(map), do: {:map, Map.new(map, fn {k, v} -> {k, of(v)} end)}

  @doc """
  Merges two types, returning a type that is a superset of both.

  ## Examples

      iex> merge(:string, :any)
      :any

      iex> merge([], :integer)
      :integer

      iex> merge(:boolean, [])
      :boolean

      iex> merge(:string, :integer)
      [:string, :integer]

      iex> merge(:string, :string)
      :string

      iex> merge({:atom, :foo}, {:atom, :bar})
      {:atom, [:foo, :bar]}

      iex> merge({:boolean, true}, {:boolean, false})
      :boolean

      iex> merge(:atom, {:atom, [:foo, :bar]})
      {:atom, [:foo, :bar]}

      iex> merge({:atom, :foo}, :atom)
      {:atom, :foo}

      iex> merge({:atom, [:bar, :baz]}, {:atom, [:foo, :bar]})
      {:atom, [:bar, :baz, :foo]}
  """
  def merge(left, right) do
    do_merge(left, right, true)
  end

  defp do_merge([], right, _union) do
    right
  end

  defp do_merge(left, [], _union) do
    left
  end

  defp do_merge(:any, _right, _union) do
    :any
  end

  defp do_merge(_left, :any, _union) do
    :any
  end

  defp do_merge(same, same, _union) do
    same
  end

  defp do_merge(type, {type, condition}, _union) do
    {type, condition}
  end

  defp do_merge({type, condition}, type, _union) do
    {type, condition}
  end

  defp do_merge({:boolean, _}, {:boolean, _}, _union) do
    :boolean
  end

  defp do_merge({type, left}, {type, right}, union) do
    {type, do_merge(left, right, union)}
  end

  defp do_merge(list, [type | rest], union) when is_list(list) do
    add(list, type)
    |> do_merge(rest, union)
  end

  defp do_merge(list, type, _union) when is_list(list) do
    add(list, type)
  end

  defp do_merge(left, right, true) do
    [left, right]
  end

  defp do_merge(_left, _right, false) do
    :error
  end

  defp add(list, type) do
    Util.Enum.try_update_or_append(list, &do_merge(&1, type, false), type)
  end
end
