defmodule Dx.Defd_.FunInfo do
  @moduledoc false

  alias Dx.Defd_.ArgInfo
  alias Dx.Defd_.FunInfo

  defstruct module: nil,
            fun_name: nil,
            arity: nil,
            args: nil,
            can_return_scope: false,
            warn_not_ok: nil,
            warn_always: nil

  @type arg_key :: non_neg_integer() | neg_integer() | :all

  @type input() :: %__MODULE__{
          module: atom() | nil,
          fun_name: atom() | nil,
          arity: non_neg_integer() | nil,
          args:
            %{arg_key() => Dx.Defd_.ArgInfo.input()}
            | list()
            | nil,
          can_return_scope: boolean(),
          warn_not_ok: binary() | nil,
          warn_always: binary() | nil
        }

  @type t() :: %__MODULE__{
          module: atom(),
          fun_name: atom(),
          arity: non_neg_integer(),
          args:
            %{arg_key() => Dx.Defd_.ArgInfo.t()}
            | list(Dx.Defd_.ArgInfo.t())
            | nil,
          can_return_scope: boolean(),
          warn_not_ok: binary() | nil,
          warn_always: binary() | nil
        }

  @doc """
  Creates a new `FunInfo` struct.

  ## Examples

      iex> new!(args: [:preload_scope], arity: 2)
      %FunInfo{args: [%ArgInfo{preload_scope: true}, %ArgInfo{}], arity: 2}

      iex> new!(args: %{0 => :preload_scope}, arity: 2)
      %FunInfo{args: [%ArgInfo{preload_scope: true}, %ArgInfo{}], arity: 2}

      iex> new!(
      ...>   args: [
      ...>     :preload_scope,
      ...>     %{},
      ...>     {:fn, arity: 2, warn_not_ok: "OOPS!"}
      ...>   ],
      ...>   arity: 3
      ...> )
      %FunInfo{
        args: [
          %ArgInfo{preload_scope: true},
          %ArgInfo{},
          %ArgInfo{
            fn: %FunInfo{
              args: [%ArgInfo{}, %ArgInfo{}],
              warn_not_ok: "OOPS!",
              arity: 2
            }
          }
        ],
        arity: 3
      }

      # Using negative indexes to count from the end
      iex> new!(args: %{0 => :preload_scope, -1 => :preload_scope}, arity: 3)
      %FunInfo{args: [%ArgInfo{preload_scope: true}, %ArgInfo{}, %ArgInfo{preload_scope: true}], arity: 3}

      # Using :all to set defaults for all arguments
      iex> new!(args: %{all: :atom_to_scope}, arity: 2)
      %FunInfo{args: [%ArgInfo{atom_to_scope: true}, %ArgInfo{atom_to_scope: true}], arity: 2}

      # Combining :all with specific indexes
      iex> new!(args: %{0 => :preload_scope, all: :atom_to_scope}, arity: 2)
      %FunInfo{args: [%ArgInfo{atom_to_scope: true, preload_scope: true}, %ArgInfo{atom_to_scope: true}], arity: 2}

      # Overriding :all defaults with specific argument settings
      iex> new!(args: %{0 => %{atom_to_scope: false}, all: :atom_to_scope}, arity: 2)
      %FunInfo{args: [%ArgInfo{atom_to_scope: false}, %ArgInfo{atom_to_scope: true}], arity: 2}

      # Error cases
      iex> new!(arity: -1)
      ** (ArgumentError) function arity must be a non-negative integer, got: -1

      iex> new!(args: %{2 => :preload_scope}, arity: 2)
      ** (ArgumentError) argument index must be less than the function's arity 2. Got 2 => :preload_scope

      iex> new!(args: %{invalid: :preload_scope}, arity: 2)
      ** (ArgumentError) Argument index must be an integer or :all. Got: :invalid

      iex> new!(args: [:preload_scope, :atom_to_scope], module: :m, fun_name: :f, arity: 1)
      ** (ArgumentError) number of arguments must be within the function's arity 1. Got 2 arguments for :m.f/1

      # Map inputs
      iex> new!(%{args: [:preload_scope], warn_not_ok: "ERROR"})
      %FunInfo{args: [:preload_scope], warn_not_ok: "ERROR"}

      iex> new!(%{args: [:preload_scope], warn_not_ok: "ERROR"}, arity: 2)
      %FunInfo{args: [%ArgInfo{preload_scope: true}, %ArgInfo{}], warn_not_ok: "ERROR", arity: 2}

      iex> new!([args: [:atom_to_scope], warn_always: "WARNING"], %{arity: 1})
      %FunInfo{args: [%ArgInfo{atom_to_scope: true}], warn_always: "WARNING", arity: 1}
  """

  @spec new!(
          input(),
          keyword() | %{atom() => term()},
          keyword() | %{atom() => term()},
          keyword() | %{atom() => term()}
        ) :: t()
  def new!(fields \\ [], extra_fields1 \\ [], extra_fields2 \\ [], extra_fields3 \\ [])

  def new!(%FunInfo{} = fun_info, extra_fields1, extra_fields2, extra_fields3) do
    fun_info
    |> struct!(extra_fields1)
    |> struct!(extra_fields2)
    |> struct!(extra_fields3)
    |> args!()
  end

  def new!(fields, extra_fields1, extra_fields2, extra_fields3) do
    FunInfo
    |> struct!(fields)
    |> new!(extra_fields1, extra_fields2, extra_fields3)
  end

  defp args!(%FunInfo{arity: nil} = fun_info), do: fun_info

  defp args!(%FunInfo{arity: arity} = fun_info) when not is_integer(arity) or arity < 0 do
    raise ArgumentError,
          "function arity must be a non-negative integer, got: #{inspect(fun_info.arity)}"
  end

  defp args!(%FunInfo{args: args} = fun_info) when is_map(args) do
    {default, args} = Map.pop(args, :all, [])

    normalized_args =
      Enum.reduce(args, args, fn
        {key, _value}, _acc when not is_integer(key) ->
          raise ArgumentError, "Argument index must be an integer or :all. Got: #{inspect(key)}"

        {i, _value}, _acc when i >= fun_info.arity ->
          raise ArgumentError,
                "argument index must be less than the function's arity #{fun_info.arity}." <>
                  " Got #{i} => #{inspect(args[i])}"

        {i, value}, acc when i < 0 ->
          Map.put_new(acc, fun_info.arity + i, value)

        {_i, _value}, acc ->
          acc
      end)

    args =
      0..(fun_info.arity - 1)
      |> Enum.map(fn i ->
        case Map.fetch(normalized_args, i) do
          {:ok, arg_info} -> ArgInfo.new!(default, arg_info)
          :error -> ArgInfo.new!(default)
        end
      end)

    %{fun_info | args: args}
  end

  defp args!(%FunInfo{args: args} = fun_info) when is_list(args) or is_nil(args) do
    args = List.wrap(args)

    if length(args) > fun_info.arity do
      raise ArgumentError,
            "number of arguments must be within the function's arity #{fun_info.arity}." <>
              " Got #{length(args)} arguments for #{inspect(fun_info.module)}.#{fun_info.fun_name}/#{fun_info.arity}"
    end

    given_args =
      args
      |> Enum.map(&ArgInfo.new!/1)

    non_given_args =
      length(given_args)..(fun_info.arity - 1)//1
      |> Enum.map(fn _i -> %ArgInfo{} end)

    args = given_args ++ non_given_args

    %{fun_info | args: args}
  end

  defp args!(_fun_info), do: raise(ArgumentError, "args must be a map or a list")
end
