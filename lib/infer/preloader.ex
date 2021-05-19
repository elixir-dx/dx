defmodule Infer.Preloader do
  @moduledoc """
  Determines preloads based on predicates to be inferred.
  """

  alias Infer.Util
  alias Infer.Evaluation, as: Eval

  @doc """
  This is the entry point for this module.
  """
  def preload_for_predicates(type, predicates, opts) when is_list(opts) do
    # see `Infer.Engine.resolve_predicate/3` for explanation
    opts = Keyword.delete(opts, :args)

    eval = Eval.from_options(opts)

    preload_for_predicates(type, predicates, eval)
  end

  def preload_for_predicates(type, predicates, %Eval{} = eval) do
    predicates
    |> expand_rules(type, eval)
    |> extract_refs()
    |> uniq_by_predicate()
    |> map_associations(type, eval)
  end

  defp expand_rules(predicates, type, %Eval{} = eval) do
    predicates
    |> deep_flatten()
    |> Enum.flat_map(fn predicate ->
      case predicate do
        {predicate, _values} ->
          Util.rules_for_predicate(predicate, type, eval)

        predicate ->
          Util.rules_for_predicate(predicate, type, eval)
      end
      |> Enum.map(&expand_rules(&1.when, type, eval))
      |> case do
        [] -> [predicate]
        rules -> rules
      end
      |> deep_flatten()
      |> filter_associations(type)
    end)
  end

  # always returns a list
  defp deep_flatten(enum) when is_list(enum) do
    Enum.flat_map(enum, &deep_flatten/1)
  end

  defp deep_flatten(enum) when is_map(enum) do
    Enum.flat_map(enum, &deep_flatten/1)
  end

  defp deep_flatten({:not, rules}) do
    deep_flatten(rules)
  end

  defp deep_flatten({key, val}) do
    [{key, deep_flatten(val)}]
  end

  defp deep_flatten(other) do
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

  defp extract_refs(predicates) do
    {predicates, ref_paths} = extract(predicates)

    Enum.flat_map(ref_paths, &path_to_preloads/1) ++ predicates
  end

  defp path_to_preloads([]), do: []
  defp path_to_preloads([elem]), do: [elem]
  defp path_to_preloads([elem | path]), do: [{elem, path_to_preloads(path)}]

  defp extract({:ref, path}) do
    {[], [path]}
  end

  defp extract({:not, predicate}) do
    extract(predicate)
  end

  defp extract({key, val}) do
    {val, extracted} = extract(val)
    {{key, val}, extracted}
  end

  defp extract(enum) when is_list(enum) do
    Enum.map_reduce(enum, [], fn elem, extracted ->
      {elem, add_extracted} = extract(elem)
      {elem, add_extracted ++ extracted}
    end)
  end

  defp extract(other), do: {other, []}

  defp uniq_by_predicate(predicates) do
    Enum.reduce(predicates, %{}, fn {predicate, sub_predicates}, acc ->
      Map.update(acc, predicate, [sub_predicates], &[sub_predicates | &1])
    end)
    |> Map.to_list()
  end

  defp map_associations(predicates, type, %Eval{} = eval) do
    Enum.map(predicates, fn
      {key, sub_predicates} ->
        sub_type = Util.Ecto.association_type(type, key)
        {key, preload_for_predicates(sub_type, sub_predicates, eval)}

      other ->
        other
    end)
  end
end
