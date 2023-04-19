defmodule Dx.Ecto.Query.Builder do
  @moduledoc """
  Internal data structure to keep track of all context needed to translate complex Dx
  rules to Ecto queries.

  ## Context switches

  ### Evaluate rule on other subject

  - Can not access existing aliases
  - Reset path
  - Keep only next alias index

  ### Subquery (EXISTS)

  - Can access existing aliases & path
  - Mark existing aliases & path entries as :parent
  - Add alias & path entry

  ### Join

  - Can access existing aliases & path
  - Add alias & path entry
  """

  use TypedStruct

  @type mapped_alias() :: {atom(), module(), %{atom() => mapped_alias()}}

  typedstruct do
    field(:query, Ecto.Query.t(), required: true)
    field(:root_query, Ecto.Query.t())
    field(:aliases, mapped_alias())
    field(:path, list(atom()), default: [])
    field(:types, list(atom()), default: [])
    field(:next_alias_index, non_neg_integer(), default: 0)
    field(:negate?, boolean(), default: false)
    field(:in_subquery?, boolean(), default: false)
    field(:eval, Dx.Evaluation.t())
  end

  alias __MODULE__, as: Builder

  import Ecto.Query, only: [dynamic: 1, from: 2, join: 5]

  def init(query, eval) do
    %Builder{root_query: query, eval: eval}
    |> set_root_alias()
  end

  defp set_root_alias(
         %{
           root_query: %Ecto.Query{
             from: %Ecto.Query.FromExpr{
               as: root_alias,
               source: {_, type}
             }
           }
         } = builder
       )
       when not is_nil(root_alias),
       do: %{builder | aliases: {root_alias, type, %{}}}

  defp set_root_alias(builder), do: builder |> do_alias() |> elem(0) |> set_root_alias()

  defp get_type(%Ecto.Query{from: %{source: {_, type}}}), do: type

  def root_alias(%Builder{aliases: {root_alias, _, _}}), do: root_alias

  def root_type(%Builder{aliases: {_, type, _}}), do: type

  def field(builder, key, maybe_parent? \\ false)

  def field(%{path: [{:parent, as} | _]}, {:field, key}, _),
    do: dynamic(field(parent_as(^as), ^key))

  def field(%{path: [as | _], in_subquery?: true}, {:field, key}, true),
    do: dynamic(field(parent_as(^as), ^key))

  def field(%{path: [as | _]}, {:field, key}, _), do: dynamic(field(as(^as), ^key))

  def field(%{path: [], aliases: {as, _, _}}, {:field, key}, _), do: dynamic(field(as(^as), ^key))

  def current_alias(%{path: [as | _]}), do: as
  def current_alias(%{path: [], aliases: {as, _, _}}), do: as

  def current_type(%{types: [type | _]}), do: type
  def current_type(%{types: [], aliases: {_, type, _}}), do: type

  def negate(builder, fun) do
    builder
    |> do_negate()
    |> fun.()
    |> case do
      {nested, result} -> {Map.put(nested, :negate?, builder.negate?), result}
      :error -> :error
    end
  end

  defp do_negate(%{negate?: prev} = builder), do: %{builder | negate?: not prev}

  defp merge(old, new) do
    %{
      old
      | root_query: new.root_query,
        aliases: new.aliases,
        next_alias_index: new.next_alias_index
    }
  end

  defp merge_query(%{query: nil} = old, new) do
    %{
      old
      | root_query: new.root_query,
        aliases: new.aliases,
        next_alias_index: new.next_alias_index
    }
  end

  defp merge_query(old, new) do
    %{
      old
      | query: new.query,
        aliases: new.aliases,
        next_alias_index: new.next_alias_index
    }
  end

  def step_into(builder, _key, subquery, fun) do
    %{builder | query: subquery, in_subquery?: true, negate?: false}
    |> add_aliased()
    |> fun.()
    |> case do
      {nested, condition} ->
        where =
          nested.query
          |> from(select: fragment("*"), where: ^condition)
          |> exists(builder)

        {merge(builder, nested), where}

      :error ->
        :error
    end
  end

  defp exists(subquery, %{negate?: false}), do: dynamic(exists(subquery))
  defp exists(subquery, %{negate?: true}), do: dynamic(not exists(subquery))

  def from_root(builder, fun) do
    %{builder | path: [], types: [], query: nil}
    |> fun.()
    |> case do
      {nested, result} -> {merge(builder, nested), result}
      :error -> :error
    end
  end

  def with_join(builder, key, fun) do
    builder
    |> add_aliased_join(key)
    |> fun.()
    |> case do
      {nested, result} -> {merge_query(builder, nested), result}
      :error -> :error
    end
  end

  defp update_query(%{query: nil} = builder, fun), do: Map.update!(builder, :root_query, fun)
  defp update_query(builder, fun), do: Map.update!(builder, :query, fun)

  def add_aliased(builder) do
    {builder, as} = do_alias(builder)
    type = get_type(builder.query)
    parent_path = Enum.map(builder.path, &{:parent, &1})

    %{builder | path: [as | parent_path], types: [type | builder.types]}
  end

  defp do_alias(builder) do
    {builder, as} = next_alias(builder)
    builder = update_query(builder, &aliased_from(&1, as))
    {builder, as}
  end

  def add_aliased_join(builder, assoc) do
    {builder, as} = next_alias(builder)
    left = current_alias(builder)

    {:assoc, _, type, %{name: name}} = assoc

    builder = update_query(builder, &aliased_join(&1, left, name, as))
    %{builder | path: [as | builder.path], types: [type | builder.types]}
  end

  defp next_alias(%{next_alias_index: i} = builder) do
    as = "a#{i}" |> String.to_existing_atom()
    builder = %{builder | next_alias_index: i + 1}
    {builder, as}
  end

  defp aliased_from(queryable, :a0), do: from(q in queryable, as: :a0)
  defp aliased_from(queryable, :a1), do: from(q in queryable, as: :a1)
  defp aliased_from(queryable, :a2), do: from(q in queryable, as: :a2)
  defp aliased_from(queryable, :a3), do: from(q in queryable, as: :a3)
  defp aliased_from(queryable, :a4), do: from(q in queryable, as: :a4)
  defp aliased_from(queryable, :a5), do: from(q in queryable, as: :a5)
  defp aliased_from(queryable, :a6), do: from(q in queryable, as: :a6)
  defp aliased_from(queryable, :a7), do: from(q in queryable, as: :a7)
  defp aliased_from(queryable, :a8), do: from(q in queryable, as: :a8)
  defp aliased_from(queryable, :a9), do: from(q in queryable, as: :a9)
  defp aliased_from(queryable, :a10), do: from(q in queryable, as: :a10)
  defp aliased_from(queryable, :a11), do: from(q in queryable, as: :a11)
  defp aliased_from(queryable, :a12), do: from(q in queryable, as: :a12)
  defp aliased_from(queryable, :a13), do: from(q in queryable, as: :a13)
  defp aliased_from(queryable, :a14), do: from(q in queryable, as: :a14)
  defp aliased_from(queryable, :a15), do: from(q in queryable, as: :a15)
  defp aliased_from(queryable, :a16), do: from(q in queryable, as: :a16)
  defp aliased_from(queryable, :a17), do: from(q in queryable, as: :a17)
  defp aliased_from(queryable, :a18), do: from(q in queryable, as: :a18)
  defp aliased_from(queryable, :a19), do: from(q in queryable, as: :a19)
  defp aliased_from(queryable, :a20), do: from(q in queryable, as: :a20)
  defp aliased_from(queryable, :a21), do: from(q in queryable, as: :a21)
  defp aliased_from(queryable, :a22), do: from(q in queryable, as: :a22)
  defp aliased_from(queryable, :a23), do: from(q in queryable, as: :a23)
  defp aliased_from(queryable, :a24), do: from(q in queryable, as: :a24)
  defp aliased_from(queryable, :a25), do: from(q in queryable, as: :a25)
  defp aliased_from(queryable, :a26), do: from(q in queryable, as: :a26)
  defp aliased_from(queryable, :a27), do: from(q in queryable, as: :a27)
  defp aliased_from(queryable, :a28), do: from(q in queryable, as: :a28)
  defp aliased_from(queryable, :a29), do: from(q in queryable, as: :a29)
  defp aliased_from(queryable, :a30), do: from(q in queryable, as: :a30)
  defp aliased_from(queryable, :a31), do: from(q in queryable, as: :a31)
  defp aliased_from(queryable, :a32), do: from(q in queryable, as: :a32)
  defp aliased_from(queryable, :a33), do: from(q in queryable, as: :a33)
  defp aliased_from(queryable, :a34), do: from(q in queryable, as: :a34)
  defp aliased_from(queryable, :a35), do: from(q in queryable, as: :a35)
  defp aliased_from(queryable, :a36), do: from(q in queryable, as: :a36)
  defp aliased_from(queryable, :a37), do: from(q in queryable, as: :a37)
  defp aliased_from(queryable, :a38), do: from(q in queryable, as: :a38)
  defp aliased_from(queryable, :a39), do: from(q in queryable, as: :a39)

  defp aliased_join(queryable, left, key, :a0),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a0)

  defp aliased_join(queryable, left, key, :a1),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a1)

  defp aliased_join(queryable, left, key, :a2),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a2)

  defp aliased_join(queryable, left, key, :a3),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a3)

  defp aliased_join(queryable, left, key, :a4),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a4)

  defp aliased_join(queryable, left, key, :a5),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a5)

  defp aliased_join(queryable, left, key, :a6),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a6)

  defp aliased_join(queryable, left, key, :a7),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a7)

  defp aliased_join(queryable, left, key, :a8),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a8)

  defp aliased_join(queryable, left, key, :a9),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a9)

  defp aliased_join(queryable, left, key, :a10),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a10)

  defp aliased_join(queryable, left, key, :a11),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a11)

  defp aliased_join(queryable, left, key, :a12),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a12)

  defp aliased_join(queryable, left, key, :a13),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a13)

  defp aliased_join(queryable, left, key, :a14),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a14)

  defp aliased_join(queryable, left, key, :a15),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a15)

  defp aliased_join(queryable, left, key, :a16),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a16)

  defp aliased_join(queryable, left, key, :a17),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a17)

  defp aliased_join(queryable, left, key, :a18),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a18)

  defp aliased_join(queryable, left, key, :a19),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a19)

  defp aliased_join(queryable, left, key, :a20),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a20)

  defp aliased_join(queryable, left, key, :a21),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a21)

  defp aliased_join(queryable, left, key, :a22),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a22)

  defp aliased_join(queryable, left, key, :a23),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a23)

  defp aliased_join(queryable, left, key, :a24),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a24)

  defp aliased_join(queryable, left, key, :a25),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a25)

  defp aliased_join(queryable, left, key, :a26),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a26)

  defp aliased_join(queryable, left, key, :a27),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a27)

  defp aliased_join(queryable, left, key, :a28),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a28)

  defp aliased_join(queryable, left, key, :a29),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a29)

  defp aliased_join(queryable, left, key, :a30),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a30)

  defp aliased_join(queryable, left, key, :a31),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a31)

  defp aliased_join(queryable, left, key, :a32),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a32)

  defp aliased_join(queryable, left, key, :a33),
    do: join(queryable, :inner, [{^left, l}], assoc(l, ^key), as: :a33)
end
