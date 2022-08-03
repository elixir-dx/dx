defmodule Dx.Schema do
  alias Dx.Schema.Type

  @lt_ops ~w(< lt less_than before)a
  @lte_ops ~w(<= lte less_than_or_equal on_or_before at_or_before)a
  @gte_ops ~w(>= gte greater_than_or_equal on_or_after at_or_after)a
  @gt_ops ~w(> gt greater_than after)a
  @all_ops @lt_ops ++ @lte_ops ++ @gte_ops ++ @gt_ops
  @primitives_1 @all_ops ++ ~w[not]a

  def expand_mapping(name, type, eval) when is_atom(name) do
    expand_atom(name, type, eval)
  end

  def expand_mapping(name, type, eval, _) do
    expand_result(name, type, eval)
  end

  def expand_result(mapping, type, eval) when is_map(mapping) do
    {expanded, types} =
      Enum.reduce(mapping, {%{}, %{}}, fn pair, {map, types} ->
        {{key, expanded}, type} = expand_result(pair, type, eval)
        map = Map.put(map, key, expanded)
        types = Map.put(types, key, type)
        {map, types}
      end)

    {expanded, {:map, types}}
  end

  def expand_result(list, type, eval) when is_list(list) do
    {list, type} =
      Enum.map_reduce(list, [], fn elem, list_type ->
        {expanded, elem_type} = expand_result(elem, type, eval)
        {expanded, Type.merge(list_type, elem_type)}
      end)

    {list, {:array, type}}
  end

  def expand_result({:ref, path}, type, eval) do
    {path, type} = expand_ref_path(path, type, eval)
    {{:ref, path}, type}
  end

  def expand_result(tuple, type, eval) when is_tuple(tuple) do
    {expanded, type} =
      tuple
      |> Tuple.to_list()
      |> expand_result(type, eval)

    {List.to_tuple(expanded), type}
  end

  def expand_result(other, _type, _eval) do
    {other, Type.of(other)}
  end

  def expand_ref_path(path, type, eval) do
    {path, {_type, result_type}} =
      Enum.map_reduce(List.wrap(path), {type, []}, fn
        name, {type, _result_type} when is_atom(name) ->
          {expanded, result_type} = expand_atom(name, type, eval)

          {expanded, {type, result_type}}
      end)

    {path, result_type}
  end

  defp expand_atom(name, type, eval) do
    case Dx.Util.rules_for_predicate(name, type, eval) do
      [] ->
        case Dx.Util.Ecto.association_details(type, name) do
          %Ecto.Association.Has{} = assoc ->
            meta =
              assoc
              |> Map.from_struct()
              |> Map.take([:ordered, :unique])
              |> Map.put(:name, name)

            {{:assoc, assoc.cardinality, assoc.queryable, meta}, assoc.queryable}

          _other ->
            case Dx.Util.Ecto.field_details(type, name) do
              nil ->
                raise ArgumentError,
                      """
                      Unknown field #{inspect(name)} on #{inspect(type)}.\
                      """

              field_type ->
                {{:field, name}, field_type}
            end
        end

      rules ->
        {expanded_rules, predicate_type} =
          Enum.map_reduce(rules, [], fn
            {condition, result}, types ->
              {result, result_type} = expand_result(result, type, eval)
              condition = expand_condition(condition, type, eval)
              {{result, condition}, Type.merge(types, result_type)}

            result, types ->
              {result, result_type} = expand_result(result, type, eval)
              {result, Type.merge(types, result_type)}
          end)

        {{:predicate, %{name: name}, expanded_rules}, predicate_type}
    end
  end

  defp expand_condition(map, type, eval) when is_map(map) do
    case map_size(map) do
      0 -> true
      1 -> map |> Enum.to_list() |> hd() |> expand_condition(type, eval)
      _ -> {:all_of, Enum.map(map, &expand_condition(&1, type, eval))}
    end
  end

  defp expand_condition(list, type, eval) when is_list(list) do
    Enum.map(list, &expand_condition(&1, type, eval))
  end

  defp expand_condition({key, other}, type, eval) when key in @primitives_1 do
    other = expand_condition(other, type, eval)
    {key, other}
  end

  defp expand_condition({left, right}, type, eval) do
    {left, type} = expand_mapping(left, type, eval)
    right = expand_condition(right, type, eval)
    {left, right}
  end

  defp expand_condition(other, _type, _eval) do
    other
  end
end
