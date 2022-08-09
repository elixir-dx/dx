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

  def expand_mapping(name, type, eval) do
    expand_result(name, type, eval)
  end

  def expand_result(%type{} = struct, parent_type, eval) do
    expanded =
      struct
      |> Map.from_struct()
      |> expand_result(parent_type, eval)

    struct(type, expanded)
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

  def expand_result({:ref, path}, _type, eval) do
    {path, type} = expand_ref_path(path, eval.root_type, eval)
    {{:ref, path}, type}
  end

  def expand_result({:bound, key}, _type, eval) do
    type = get_bound(key, eval)
    {{:bound, key}, type}
  end

  def expand_result({:map, source, each_key, each_val}, type, eval) do
    {source, source_type} = expand_mapping(source, type, eval)

    each_type =
      case source_type do
        {:array, type} ->
          type

        type ->
          raise ArgumentError,
                "{:map, source, ...} must evaluate to an array type. Got: #{inspect(type)}"
      end

    {each_key, eval} =
      case each_key do
        {:bind, key, conditions} when is_atom(key) ->
          conditions = expand_condition(conditions, type, eval)
          each_key = {:bind, key, conditions}
          eval = put_in(eval.binds[key], each_type)
          {each_key, eval}

        {:bind, key} when is_atom(key) ->
          eval = put_in(eval.binds[key], each_type)
          {each_key, eval}

        key when is_atom(key) ->
          eval = put_in(eval.binds[key], each_type)
          {each_key, eval}
      end

    {each_val, type} = expand_result(each_val, source_type, eval)
    {{:map, source, each_key, each_val}, type}
  end

  # def expand_result({query_type, type, conditions}, type, eval)
  #     when query_type in [:query_one, :query_first] do
  #   conditions = expand_condition(conditions, type, eval)
  #   {{query_type, type, conditions}, Type.merge(type, nil)}
  # end

  def expand_result({function, args}, type, eval) when is_function(function) do
    args =
      Enum.map(List.wrap(args), fn arg ->
        {arg, _type} = expand_result(arg, type, eval)
        arg
      end)

    {{function, args}, :any}
  end

  def expand_result({function, args, opts}, type, eval) when is_function(function) do
    result_type =
      case Keyword.pop(opts, :type) do
        {type, []} ->
          type

        {_, other_opts} ->
          raise ArgumentError, "Unknown options: #{inspect(other_opts, pretty: true)}"
      end

    args =
      Enum.map(List.wrap(args), fn arg ->
        {arg, _type} = expand_result(arg, type, eval)
        arg
      end)

    {{function, args}, result_type}
  end

  def expand_result(tuple, type, eval) when is_tuple(tuple) do
    case tuple do
      {query_type, type, conditions} when query_type in [:query_one, :query_first] ->
        conditions = expand_condition(conditions, type, eval)
        {{query_type, type, conditions}, Type.merge(type, nil)}

      {query_type, type, conditions, opts} when query_type in [:query_one, :query_first] ->
        conditions = expand_condition(conditions, type, eval)
        {{query_type, type, conditions, opts}, Type.merge(type, nil)}

      {:query_all, type, conditions} ->
        conditions = expand_condition(conditions, type, eval)
        {{:query_all, type, conditions}, {:array, type}}

      {:query_all, type, conditions, opts} ->
        conditions = expand_condition(conditions, type, eval)
        {{:query_all, type, conditions, opts}, {:array, type}}

      tuple ->
        {expanded, type} =
          tuple
          |> Tuple.to_list()
          |> expand_result(type, eval)

        {List.to_tuple(expanded), type}
    end
  end

  def expand_result(other, _type, _eval) do
    {other, Type.of(other)}
  end

  defp expand_ref_path(path, type, eval) do
    do_expand_ref_path(List.wrap(path), type, eval, [])
  end

  defp do_expand_ref_path([], type, _eval, acc) do
    {Enum.reverse(acc), type}
  end

  defp do_expand_ref_path([:args, name | path], _type, eval, acc) when is_atom(name) do
    arg = eval.args[name]
    type = Type.of(arg)
    do_expand_ref_path(path, type, eval, [name, :args | acc])
  end

  defp do_expand_ref_path([map | path], type, eval, acc) when is_map(map) do
    {expanded, types} =
      Enum.reduce(map, {%{}, %{}}, fn {key, val}, {map, types} ->
        {expanded, type} = expand_ref_path(val, type, eval)
        map = Map.put(map, key, expanded)
        types = Map.put(types, key, type)
        {map, types}
      end)

    do_expand_ref_path(path, {:map, types}, eval, [expanded | acc])
  end

  defp do_expand_ref_path([list | path], type, eval, acc) when is_list(list) do
    {expanded, types} =
      Enum.reduce(list, {%{}, %{}}, fn
        name, {map, types} when is_atom(name) ->
          {expanded, type} = expand_atom(name, type, eval)
          map = Map.put(map, name, expanded)
          types = Map.put(types, name, type)
          {map, types}

        other, _ ->
          raise ArgumentError,
                "A nested list in a {:ref, ...} can only contain atoms. Got " <>
                  inspect(other, pretty: true)
      end)

    do_expand_ref_path(path, {:map, types}, eval, [expanded | acc])
  end

  defp do_expand_ref_path([name | path], type, eval, acc) when is_atom(name) do
    {expanded, type} = expand_atom(name, type, eval)
    do_expand_ref_path(path, type, eval, [expanded | acc])
  end

  defp expand_atom(name, {:array, type}, eval) do
    {expanded, type} = expand_atom(name, type, eval)
    {expanded, {:array, type}}
  end

  defp expand_atom(name, [type, nil], eval) do
    {expanded, type} = expand_atom(name, type, eval)
    {expanded, Type.merge(type, nil)}
  end

  defp expand_atom(:args, type, eval) do
    types = Map.new(eval.args, fn {key, val} -> {key, Type.of(val)} end)
    {:args, {:map, types}}
  end

  defp expand_atom(name, {:map, types}, eval) when is_atom(name) do
    type =
      case Map.fetch(types, name) do
        {:ok, type} ->
          type

        :error ->
          raise ArgumentError, "Type #{name} not found in {:map, #{inspect(types, pretty: true)}}"
      end

    {name, type}
  end

  defp expand_atom(name, type, eval) do
    case Dx.Util.rules_for_predicate(name, type, eval) do
      [] ->
        case Dx.Util.Ecto.association_details(type, name) do
          # can be Ecto.Association.Has or Ecto.Association.BelongsTo
          %_{} = assoc ->
            meta =
              assoc
              |> Map.from_struct()
              |> Map.take([:ordered, :owner_key, :related_key, :unique])
              |> Map.put(:name, name)

            type =
              case assoc.cardinality do
                :one -> [assoc.queryable, nil]
                :many -> {:array, assoc.queryable}
              end

            {{:assoc, assoc.cardinality, assoc.queryable, meta}, type}

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
        eval = %{eval | root_type: type}

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

  def expand_condition(map, type, eval) when is_map(map) do
    case map_size(map) do
      0 -> {:all, []}
      1 -> map |> Enum.to_list() |> hd() |> expand_condition(type, eval)
      _ -> {:all, Enum.map(map, &expand_condition(&1, type, eval))}
    end
  end

  def expand_condition({:all, []}, _type, _eval) do
    {:all, []}
  end

  def expand_condition({:all, [condition]}, type, eval) do
    expand_condition(condition, type, eval)
  end

  def expand_condition({:all, conditions}, type, eval) do
    {:all, Enum.map(conditions, &expand_condition(&1, type, eval))}
  end

  def expand_condition(list, type, eval) when is_list(list) do
    Enum.map(list, &expand_condition(&1, type, eval))
  end

  def expand_condition({:bound, key}, _type, eval) do
    get_bound(key, eval)
  end

  def expand_condition({left, {:bind, bind_key, right}}, type, eval) do
    eval = put_in(eval.binds[bind_key], type)
    right = expand_condition(right, type, eval)
    {left, right}
  end

  def expand_condition({key, other}, type, eval) when key in @primitives_1 do
    other = expand_condition(other, type, eval)
    {key, other}
  end

  def expand_condition({left, right}, type, eval) when is_map(right) do
    {left, left_type} = expand_mapping(left, type, eval)
    right = expand_condition(right, left_type, eval)
    {left, right}
  end

  def expand_condition({left, right}, type, eval) do
    {left, _type} = expand_mapping(left, type, eval)
    {right, _type} = expand_result(right, eval.root_type, eval)
    {left, right}
  end

  def expand_condition(other, _type, _eval) do
    other
  end

  defp get_bound(key, eval) do
    if not is_atom(key) do
      raise ArgumentError, "Binding reference can only be an atom. Got #{inspect(key)}"
    end

    case Map.fetch(eval.binds, key) do
      {:ok, bind} ->
        bind

      :error ->
        raise ArgumentError, "Unknown binding reference: #{inspect(key)}"
    end
  end
end
