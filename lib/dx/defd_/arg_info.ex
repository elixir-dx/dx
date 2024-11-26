defmodule Dx.Defd_.ArgInfo do
  @moduledoc false

  alias Dx.Defd_.ArgInfo
  alias Dx.Defd_.FunInfo

  defstruct atom_to_scope: false,
            preload_scope: false,
            fn: false,
            final_args_fn: false

  @type input() ::
          :atom_to_scope
          | :preload_scope
          | :fn
          | :final_args_fn
          | list(
              :atom_to_scope
              | :preload_scope
              | {:preload_scope, boolean()}
              | :fn
              | :final_args_fn
              | tuple()
            )
          | %__MODULE__{
              atom_to_scope: boolean(),
              preload_scope: boolean(),
              fn: FunInfo.input() | nil,
              final_args_fn: FunInfo.input() | nil
            }

  @type t() :: %__MODULE__{
          atom_to_scope: boolean(),
          preload_scope: boolean(),
          fn: FunInfo.t() | nil,
          final_args_fn: FunInfo.t() | nil
        }

  @fun_fields [:fn, :final_args_fn]

  @spec new!(input()) :: t()
  def new!(%ArgInfo{} = arg_info), do: arg_info
  def new!(field) when is_atom(field), do: new!([field])

  def new!(fields) when is_list(fields) or is_map(fields),
    do: struct!(ArgInfo, Enum.map(fields, &field!/1))

  def new!(fields), do: new!(List.wrap(fields))

  defp field!(field) when field in @fun_fields, do: {field, FunInfo.new!()}
  defp field!(field) when is_atom(field), do: {field, true}

  defp field!(tuple) when is_tuple(tuple) and elem(tuple, 0) in @fun_fields,
    do: {elem(tuple, 0), fun_info!(tuple)}

  defp field!({field, value}) when is_atom(field), do: {field, value}

  defp fun_info!(tuple) when is_tuple(tuple) do
    fields =
      tuple
      |> Tuple.to_list()
      |> Enum.drop(1)
      |> List.flatten()

    FunInfo.new!(fields)
  end
end
