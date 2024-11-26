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

  @type input() :: %__MODULE__{
          module: atom() | nil,
          fun_name: atom() | nil,
          arity: non_neg_integer() | nil,
          args:
            %{non_neg_integer() => Dx.Defd_.ArgInfo.input()}
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
            %{non_neg_integer() => Dx.Defd_.ArgInfo.t()}
            | list(Dx.Defd_.ArgInfo.t())
            | nil,
          can_return_scope: boolean(),
          warn_not_ok: binary() | nil,
          warn_always: binary() | nil
        }

  @doc """
  Creates a new `FunInfo` struct.

  ## Examples

      iex> new!(%{args: [:preload_scope]}, %{arity: 2})
      %FunInfo{arity: 2, args: [%ArgInfo{preload_scope: true}, %ArgInfo{}]}

      iex> new!(%{args: %{0 => :preload_scope}}, %{arity: 2})
      %FunInfo{arity: 2, args: [%ArgInfo{preload_scope: true}, %ArgInfo{}]}

      iex> new!(
      ...>   %{args: [
      ...>     :preload_scope,
      ...>     %{},
      ...>     {:fn, arity: 2, warn_not_ok: "OOPS!"}
      ...>   ]},
      ...>   %{arity: 3}
      ...> )
      %FunInfo{
        arity: 3,
        args: [
          %ArgInfo{preload_scope: true},
          %ArgInfo{},
          %ArgInfo{
            fn: %FunInfo{
              arity: 2,
              warn_not_ok: "OOPS!",
              args: [%ArgInfo{}, %ArgInfo{}]
            }
          }
        ]
      }
  """

  @spec new!(input(), keyword() | %{atom() => term()}) :: t()
  def new!(fun_info \\ %FunInfo{}, extra_fields \\ [])

  def new!(%FunInfo{} = fun_info, extra_fields) do
    fun_info
    |> struct!(extra_fields)
    |> args!()
  end

  def new!(fields, extra_fields) do
    FunInfo
    |> struct!(fields)
    |> new!(extra_fields)
  end

  defp args!(%FunInfo{arity: nil} = fun_info), do: fun_info

  defp args!(%FunInfo{arity: arity} = fun_info) when not is_integer(arity) or arity < 0 do
    raise ArgumentError,
          """
          function arity must be a non-negative integer, got: #{inspect(fun_info.arity)}

          #{inspect(fun_info, pretty: true)}
          """
  end

  defp args!(%FunInfo{args: args} = fun_info) when is_map(args) do
    Enum.each(args, fn {i, arg_info} ->
      if i >= fun_info.arity do
        raise ArgumentError,
              "argument index must be less than the function's arity #{fun_info.arity}." <>
                " Got #{i} => #{inspect(arg_info)}"
      end
    end)

    args =
      0..(fun_info.arity - 1)
      |> Enum.map(fn i ->
        case Map.fetch(args, i) do
          {:ok, arg_info} -> ArgInfo.new!(arg_info)
          :error -> %ArgInfo{}
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
