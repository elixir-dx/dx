defmodule Infer.Util do
  @moduledoc """
  Helpers needed in several core modules.
  """

  alias __MODULE__, as: Util
  alias Infer.Evaluation, as: Eval

  def rules_for_predicate(predicate, type, %Eval{} = eval) do
    extra_rules =
      eval.extra_rules
      |> Enum.flat_map(&rules_from_module/1)
      |> Enum.filter(&(&1.type in [nil, type]))

    (extra_rules ++ rules_from_module(type))
    |> Enum.filter(&(&1.key == predicate))
  end

  defp rules_from_module(type) do
    if Util.Module.has_function?(type, :infer_rules, 0) do
      type.infer_rules()
    else
      []
    end
  end

  @doc """
  When given `{:ok, result}`, applies the given function to `result` and returns `{:ok, new_result}`.
  Otherwise, returns first argument as is.
  """
  def map_ok_result({:ok, result}, mapper), do: {:ok, mapper.(result)}
  def map_ok_result(other, _mapper), do: other

  @doc """
  When given `{:ok, result}`, applies the given function to `result` and returns the result of the call.
  Otherwise, returns first argument as is.
  """
  def if_ok({:ok, result}, fun), do: fun.(result)
  def if_ok(other, _fun), do: other
end
