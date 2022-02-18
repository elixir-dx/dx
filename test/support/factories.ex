defmodule Test.Support.Factories do
  def refinement(Infer.Test.Schema.User, :default) do
    %{
      email: "alice@acme.org"
    }
  end

  def refinement(Infer.Test.Schema.List, :default) do
    %{
      title: "My List"
    }
  end

  def refinement(Infer.Test.Schema.Task, :default) do
    %{
      title: "My Task"
    }
  end

  def refinement(_type, _refinement), do: nil

  def build(module, refinements \\ %{})

  @doc """
  Takes a schema type and returns an instance of it with the following layers of data applied:

    1. Defaults for this type defined as `refinement(type, :default)`
    2. `refinements` passed as second argument
    3. For all referenced associations,
      a) Defaults for the association type defined in `build/1`
      b) Defaults passed by the previous layer, e.g.
        `%Offer{department: %{name: "Construction"}}` will override
        the `:name` on the associated `Department`
      c) `refinements` passed for this specific association name, e.g.
        passing `%{department: %{name: "Carpentry"}}` will override the `:name`
        of any `Department` directly or indirectly associated in the current branch
  """
  def build(module, refinements) do
    case resolve_refinement(module, {:default, refinements}) do
      record = %{__struct__: ^module} ->
        record

      record = %{__struct__: _module} ->
        raise ArgumentError, "Expected a struct of type #{module}. Got #{inspect(record)}"

      attrs ->
        do_build(module, attrs)
    end
  end

  def do_build(module, attrs) do
    record = struct!(module, attrs)

    # set associations in record
    Enum.reduce(attrs, record, fn {name, refinements}, record ->
      assoc =
        case ecto_association(module, name) || ecto_embed(module, name) do
          %Ecto.Association.BelongsTo{related: type} -> {:build_one, type}
          %Ecto.Association.Has{cardinality: :one, related: type} -> {:build_one, type}
          %Ecto.Embedded{cardinality: :one, related: type} -> {:build_one, type}
          _ -> :skip
        end

      case {assoc, refinements} do
        {{:build_one, type}, %type{}} ->
          record

        {{:build_one, type}, %other_type{}} ->
          raise ArgumentError,
                "Expected value of type #{type} for #{module}.#{name}. Got #{other_type}"

        {{:build_one, _type}, nil} ->
          Map.put(record, name, nil)

        {{:build_one, type}, _} ->
          associated_record = build(type, refinements)
          Map.put(record, name, associated_record)

        {:skip, _} ->
          record
      end
    end)
  end

  defp resolve_refinement(type, :default) do
    refinement(type, :default) || %{}
  end

  defp resolve_refinement(type, refinement) do
    refinement(type, refinement) || merge_refinements(type, refinement, %{})
  end

  defp merge_refinements(type, refinements, result) when is_tuple(refinements) do
    refinements
    |> Tuple.to_list()
    |> Enum.reduce(result, &deep_merge(&2, resolve_refinement(type, &1), false, true))
  end

  defp merge_refinements(_type, refinements, result) when is_map(refinements) do
    deep_merge(result, refinements, false)
  end

  defp merge_refinements(type, refinement, _result) do
    raise ArgumentError, "Unknown refinement for #{type}: #{inspect(refinement)}"
  end

  defp ecto_association(module, name), do: module.__schema__(:association, name)
  defp ecto_embed(module, name), do: module.__schema__(:embed, name)

  defp deep_merge(left, right, concat_lists? \\ true, struct_overrides? \\ false) do
    Map.merge(left, right, &deep_resolve(&1, &2, &3, concat_lists?, struct_overrides?))
  end

  defp deep_resolve(_key, _left, %{__struct__: _type} = right, _concat_lists?, true) do
    right
  end

  defp deep_resolve(
         _key,
         %{__struct__: type} = left,
         %{__struct__: type} = right,
         _concat_lists?,
         _struct_overrides?
       ) do
    struct!(type, deep_merge(Map.from_struct(left), Map.from_struct(right)))
  end

  defp deep_resolve(_key, %{__struct__: type}, _right, _concat_lists?, _struct_overrides?) do
    raise ArgumentError, "#{type} cannot be merged with non-#{type}."
  end

  defp deep_resolve(_key, _left, %{__struct__: type}, _concat_lists?, _struct_overrides?) do
    raise ArgumentError, "Non-#{type} cannot be merged with #{type}."
  end

  defp deep_resolve(_key, %{} = left, %{} = right, _concat_lists?, _struct_overrides?) do
    deep_merge(left, right)
  end

  defp deep_resolve(_key, left, right, true, _struct_overrides?)
       when is_list(left) and is_list(right) do
    left ++ right
  end

  defp deep_resolve(_key, _left, right, _concat_lists?, _struct_overrides?), do: right
end
