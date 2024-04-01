defmodule Dx.Util do
  @moduledoc """
  Helpers needed in several core modules.
  """

  alias __MODULE__, as: Util
  alias Dx.Evaluation, as: Eval

  def rules_for_predicate(predicate, type, %Eval{} = eval) do
    extra_rules =
      eval.extra_rules
      |> Enum.flat_map(&rules_from_module(&1, predicate, type, required?: true))

    extra_rules ++ rules_from_module(type, predicate, type)
  end

  defp rules_from_module(mod, predicate, type, ops \\ []) do
    required? = Keyword.get(ops, :required?, false)
    compiled = Code.ensure_compiled(mod)

    cond do
      Util.Module.has_function?(mod, :dx_rules_for, 2) ->
        mod.dx_rules_for(predicate, type)

      required? ->
        raise(Dx.Error.RulesNotFound, module: mod, compiled: compiled)

      true ->
        []
    end
  end

  def if(term, nil, _fun), do: term
  def if(term, false, _fun), do: term
  def if(term, _truthy, fun), do: fun.(term)

  @doc """
  Merges two nested maps recursively.
  """
  def deep_merge(%type{} = left, %type{} = right) do
    Map.merge(left, right, fn _key, left, right -> deep_merge(left, right) end)
  end

  def deep_merge(%_{} = _left, %_{} = right) do
    right
  end

  def deep_merge(%{} = left, %{} = right) do
    Map.merge(left, right, fn _key, left, right -> deep_merge(left, right) end)
  end

  def deep_merge(left, right) when is_list(left) and is_list(right) do
    left ++ right
  end

  def deep_merge(_left, right), do: right
end
