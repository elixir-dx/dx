defmodule Dx.Scope do
  @moduledoc """
  ## Components

  ### Meta function

  Each defd function also compiles to a meta function that's a middle ground between
  an AST representation and running the actual code.

  It's usually called at runtime.

  It has the same arguments as the actual function, but what gets passed in is different:

  - when the data it represents is already loaded (i.e. passed in from non-defd context,
    incl. preloads), `type` is passed in
  - otherwise, a scope is passed in, e.g. `%Dx.Scope{}`

  #### Example

  This simple function with a filter:

  ```elixir
  defd non_archived(lists) do
    Enum.filter(lists, &is_nil(&1.archived_at))
  end
  ```

  can either be called on already loaded (i.e. passed in) data, e.g.

  ```elixir
  lists = Repo.all(TodoList)
  load!(non_archived(lists))
  ```

  then the meta function gets called with `{:array, TodoList}` and returns the same term.

  Or it can be called on a scope, e.g.

  ```elixir
  defd all_non_archived_lists() do
    TodoList
    |> non_archived()
  end
  ```

  then the meta function gets called with `%Dx.Scope{type: TodoList}` and returns
  `%Dx.Scope{type: TodoList, query_conditions: [archived_at: nil]}`.

  ### Partial scope coverage

  Sometimes, a scope can cover only a subset of the not-loaded data.

  A meta function can thus return either

  - {:ok, scope} if it is fully scopable
  - :error if not

  ### later ...
  - {:error, loader} if none of it is scopable
  - {:partial, scope, loader} if a part of it is scopable

  `loader` is a function that can be called just like a defd function,
  i.e. it can return `{:ok, result}` or `{:not_loaded, data_reqs}`.
  """

  defstruct [
    :plan,
    :type,
    cardinality: :many,
    aggregate_default: nil,
    ref: :root,
    query_conditions: true,
    main_condition_candidates: nil,
    post_load: {:loaded},
    opts: []
  ]

  def all(module) do
    %__MODULE__{type: module, plan: {:queryable, module}}
  end

  def maybe_lookup(%__MODULE__{} = scope, eval), do: lookup(scope, eval)
  def maybe_lookup(other, _eval), do: {:ok, other}

  def maybe_load({:ok, %__MODULE__{} = scope}, eval), do: lookup(scope, eval)
  def maybe_load(other, _eval), do: other

  def lookup(scope, eval) do
    eval.loader.lookup(eval.cache, scope, false)
    |> case do
      {:ok, [{results, scope}]} ->
        results
        |> Dx.Ecto.Scope.run_post_load(scope.post_load, eval)

      {:ok, {result, scope}} ->
        result
        |> Dx.Ecto.Scope.run_post_load(scope.post_load, eval)

      other ->
        other
    end
  end

  def to_data_req(%__MODULE__{} = scope) do
    {combination, scope} = extract_main_condition_candidates(scope)

    %{scope => MapSet.new([combination])}
  end

  def extract_main_condition_candidates(%__MODULE__{} = scope) do
    {:ok, scope} = Dx.Ecto.Scope.resolve(scope)
    {candidates, plan} = main_condition_candidates(scope.plan)
    fields = Map.keys(candidates) |> Enum.sort()
    scope = %{scope | plan: plan, main_condition_candidates: fields}

    {candidates, scope}
  end

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

  defp to_main_condition_candidates({:eq, {:field, {:ref, :a0}, field}, {:value, value}}) do
    {%{field => value}, true}
  end

  defp to_main_condition_candidates({:eq, {:value, value}, {:field, {:ref, :a0}, field}}) do
    {%{field => value}, true}
  end

  defp to_main_condition_candidates(other) do
    {%{}, other}
  end

  def field_or_assoc(base, field) do
    %__MODULE__{plan: {:field_or_assoc, base, field}}
  end

  def eq(left, right) do
    {:eq, left, right}
  end

  def add_conditions(scope, %Dx.Defd.Fn{scope: fun}) do
    add_conditions(scope, fun)
  end

  def add_conditions(scope, new_conditions) when is_map(new_conditions) do
    Enum.reduce(new_conditions, scope, fn {field, value}, scope ->
      add_conditions(scope, {:eq, {:field, {:ref, :a0}, field}, {:value, value}})
    end)
  end

  def add_conditions(scope, new_condition) do
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
