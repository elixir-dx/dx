defmodule Dx.Scope do
  @moduledoc """
  Used as intermediate data structure to translating defd code to SQL.
  """

  @typedoc """
  A scope struct used for translating defd code to SQL queries.

  Fields:
  - `:plan` - The query plan to be executed
  - `:type` - The schema module type
  - `:cardinality` - Either `:one` or `:many` (default: `:many`)
  - `:aggregate?` - Whether this scope represents an aggregate query
  - `:aggregate_default` - Default value to use for empty aggregates (e.g. `0` for `count`)
  - `:ref` - Root alias when building the Ecto query (default: `:root`)
  - `:main_condition_candidates` - Candidates for the main query condition
  - `:post_load` - Post-processing defd functions to apply after loading (default: `{:loaded}`),
                   e.g. filters that could not be translated to SQL
  - `:opts` - Additional options (default: `[]`)
  """
  @type t :: %__MODULE__{
          plan: term(),
          type: module(),
          cardinality: :one | :many,
          aggregate?: boolean(),
          aggregate_default: term(),
          ref: atom(),
          main_condition_candidates: term(),
          post_load: {:loaded} | term(),
          opts: keyword()
        }

  defstruct [
    :plan,
    :type,
    cardinality: :many,
    aggregate?: false,
    aggregate_default: nil,
    ref: :root,
    main_condition_candidates: nil,
    post_load: {:loaded},
    opts: []
  ]

  import Dx.Defd.Ast.Guards

  @doc """
  Explicitly create an unfiltered scope for a schema module.
  """
  def all(module) do
    %__MODULE__{type: module, plan: {:queryable, module}}
  end

  @doc """
  Converts an atom to a scope using `all/1` if given an atom, otherwise returns the input unchanged.
  """
  def maybe_atom(atom) when is_atom(atom), do: all(atom)
  def maybe_atom(other), do: other

  @doc """
  Looks up a scope if given one, otherwise wraps the input in an `:ok` tuple.
  """
  def maybe_lookup(%__MODULE__{} = scope, eval), do: lookup(scope, eval)
  def maybe_lookup(other, _eval), do: {:ok, other}

  @doc """
  Looks up a scope if given {:ok, scope}, otherwise returns the input unchanged.
  """
  def maybe_load({:ok, %__MODULE__{} = scope}, eval), do: lookup(scope, eval)
  def maybe_load(other, _eval), do: other

  @doc """
  Looks up a scope using the provided `Dx.Evaluation` struct.
  Runs any post-load processing defined in the scope.
  """
  def lookup(scope, eval) do
    eval.loader.lookup(eval.cache, scope, false)
    |> case do
      {:ok, [{results, scope}]} ->
        {:ok, results}
        |> Dx.Ecto.Scope.run_post_load(scope.post_load, eval)

      {:ok, {result, scope}} ->
        {:ok, result}
        |> Dx.Ecto.Scope.run_post_load(scope.post_load, eval)

      other ->
        other
    end
  end

  @doc false
  def to_data_req(%__MODULE__{} = scope) do
    {combination, scope} = extract_main_condition_candidates(scope)

    %{scope => MapSet.new([combination])}
  end

  @doc false
  def extract_main_condition_candidates(%__MODULE__{} = scope) do
    {:ok, scope} = Dx.Ecto.Scope.resolve(scope)
    {candidates, plan} = main_condition_candidates(scope.plan)
    fields = Map.keys(candidates) |> Enum.sort()
    scope = %{scope | plan: plan, main_condition_candidates: fields}

    {candidates, scope}
  end

  @doc false
  def main_condition_candidates({:filter, base, condition}) do
    case to_main_condition_candidates(condition) do
      {candidates, true} -> {candidates, base}
      {candidates, condition} -> {candidates, {:filter, base, condition}}
    end
  end

  def main_condition_candidates({:count, base}) do
    {candidates, plan} = base |> main_condition_candidates()

    {candidates, {:count, plan}}
  end

  def main_condition_candidates(other) do
    {%{}, other}
  end

  defp to_main_condition_candidates({:all_of, conditions}) do
    Enum.reduce(conditions, {%{}, []}, fn
      condition, {candidates, remaining} ->
        case to_main_condition_candidates(condition) do
          {new_candidates, true} ->
            {Map.merge(new_candidates, candidates), remaining}

          {new_candidates, new_remaining} ->
            {Map.merge(new_candidates, candidates), [new_remaining | remaining]}
        end
    end)
    |> case do
      {candidates, []} ->
        {candidates, true}

      {candidates, [remaining]} ->
        {candidates, remaining}

      {candidates, remaining} ->
        {candidates, {:all_of, :lists.reverse(remaining)}}
    end
  end

  defp to_main_condition_candidates({:eq, {:field, _type, {:ref, :a0}, field}, value})
       when is_simple(value) do
    {%{field => value}, true}
  end

  defp to_main_condition_candidates({:eq, value, {:field, _type, {:ref, :a0}, field}})
       when is_simple(value) do
    {%{field => value}, true}
  end

  defp to_main_condition_candidates(other) do
    {%{}, other}
  end

  def map_plan(scope, fun) do
    Map.update!(scope, :plan, fun)
  end

  def add_conditions(scope, %Dx.Defd.Fn{scope: fun}) do
    do_add_conditions(scope, fun)
  end

  def add_conditions(scope, ext_ok_fun) when is_function(ext_ok_fun) do
    Map.update!(scope, :post_load, &{:filter, ext_ok_fun, &1})
  end

  def add_conditions(scope, new_conditions) when is_map(new_conditions) do
    Enum.reduce(new_conditions, scope, fn {field, value}, scope ->
      do_add_conditions(scope, {:eq, {:field, :unknown, {:ref, :a0}, field}, value})
    end)
  end

  defp do_add_conditions(scope, new_condition) do
    Map.update!(scope, :plan, fn
      {:filter, plan, {:all_of, conditions}} ->
        {:filter, plan, {:all_of, conditions ++ [new_condition]}}

      {:filter, plan, condition} ->
        {:filter, plan, {:all_of, [condition, new_condition]}}

      plan ->
        {:filter, plan, new_condition}
    end)
  end
end
