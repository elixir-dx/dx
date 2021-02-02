defmodule Infer.Preloader do
  @moduledoc """
  Determines preloads based on predicates to be inferred.
  """

  alias Infer.{Engine, Util}

  def preload_for_predicates(type, predicates) do
    predicates
    |> expand_rules(type)
    |> uniq_by_predicate()
    |> map_associations(type)
  end

  defp map_associations(predicates, type) do
    Enum.map(predicates, fn
      {key, sub_predicates} ->
        sub_type = Util.Ecto.association_type(type, key)
        {key, preload_for_predicates(sub_type, sub_predicates)}

      other ->
        other
    end)
  end

  defp expand_rules(predicates, type) do
    predicates
    |> flatttten()
    |> Enum.flat_map(fn predicate ->
      case predicate do
        {predicate, values} ->
          Engine.rules_for_predicate(predicate, type)
          |> Enum.filter(&(&1.val in values))

        predicate ->
          Engine.rules_for_predicate(predicate, type)
      end
      |> Enum.map(&expand_rules(&1.when, type))
      |> case do
        [] -> [predicate]
        rules -> rules
      end
      |> flatttten()
      |> filter_associations(type)
    end)
  end

  # always returns a list
  defp flatttten(enum) when is_list(enum) do
    Enum.flat_map(enum, &flatttten/1)
  end

  defp flatttten(enum) when is_map(enum) do
    Enum.flat_map(enum, &flatttten/1)
  end

  defp flatttten({key, val}) do
    [{key, flatttten(val)}]
  end

  defp flatttten(other) do
    [other]
  end

  defp filter_associations(predicates, type) do
    associations = Util.Ecto.association_names(type)

    Enum.flat_map(predicates, fn
      {key, val} ->
        if key in associations, do: [{key, val}], else: []

      key ->
        if key in associations, do: [key], else: []
    end)
  end

  defp uniq_by_predicate(predicates) do
    Enum.reduce(predicates, %{}, fn {predicate, sub_predicates}, acc ->
      Map.update(acc, predicate, [sub_predicates], &[sub_predicates | &1])
    end)
    |> Map.to_list()
  end
end
