defmodule Infer.Util do
  @moduledoc """
  Helpers needed in several core modules.
  """

  alias __MODULE__, as: Util
  alias Infer.Evaluation, as: Eval

  def rules_for_predicate(predicate, type, %Eval{} = eval) do
    extra_rules =
      eval.extra_rules
      |> Enum.flat_map(&rules_from_module(&1, predicate, type))

    extra_rules ++ rules_from_module(type, predicate, type)
  end

  defp rules_from_module(mod, predicate, type) do
    if Util.Module.has_function?(mod, :infer_rules_for, 2) do
      mod.infer_rules_for(predicate, type)
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
