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
  Merges two nested maps recursively.
  """
  def deep_merge(%{} = left, %{} = right) do
    Map.merge(left, right, fn _key, left, right -> deep_merge(left, right) end)
  end

  def deep_merge(left, right) when is_list(left) and is_list(right) do
    left ++ right
  end

  def deep_merge(_left, right), do: right
end
