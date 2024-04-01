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

  defstruct [:plan, :type, cardinality: :all, ref: :root, query_conditions: true, opts: []]

  def all(module) do
    %__MODULE__{type: module, plan: {:queryable, module}}
  end

  # def maybe_lookup({:ok, %__MODULE__{} = scope}, eval), do: lookup(scope, eval)
  def maybe_lookup(%__MODULE__{} = scope, eval), do: lookup(scope, eval)
  # def maybe_lookup(%__MODULE__.Loaded{data: data}, _eval), do: {:ok, data}
  # def maybe_lookup(other, _eval), do: dbg(other)
  def maybe_lookup(other, _eval), do: {:ok, other}

  def maybe_load({:ok, %__MODULE__{} = scope}, eval), do: lookup(scope, eval)
  def maybe_load(other, _eval), do: other

  def lookup(scope, eval) do
    eval.loader.lookup(eval.cache, scope, false)
    |> dbg()
    |> case do
      {:ok, [{results, post_load}]} ->
        Dx.Ecto.Scope.run_post_load(results, post_load, eval)

      other ->
        other
    end

    # |> IO.inspect(label: :LOOKUP)
  end

  def field_or_assoc(base, field) do
    # %{scope | plan: {:field, scope.plan, field}}
    # all({:field, scope, field})
    # {:field, base, field}
    %__MODULE__{plan: {:field, base, field}}
  end

  def eq(left, right) do
    {:eq, left, right}
  end

  def add_conditions(scope, %Dx.Defd.Fn{scope: fun}) do
    add_conditions(scope, fun)
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

    # Map.update!(scope, :query_conditions, fn
    #   true -> new_condition
    #   {:all_of, conditions} -> {:all_of, conditions ++ [new_condition]}
    #   condition -> {:all_of, [condition, new_condition]}
    # end)
  end

  # def add_conditions(scope, conditions) when is_map(conditions) do
  #   add_conditions(scope, Enum.to_list(conditions))
  # end

  # def add_conditions(scope, conditions) when is_list(conditions) do
  #   Map.update!(scope, :query_conditions, &(&1 ++ conditions))
  # end

  # def add_conditions(scope, _) do
  #   add_conditions(scope, [])
  # end

  def resolve(true, _scope), do: true
  def resolve(fun, scope) when is_function(fun, 1), do: fun.(scope) |> resolve(scope)

  def resolve({:all_of, conditions}, scope),
    do: {:all_of, Enum.map(conditions, &resolve(&1, scope))}

  def resolve({:eq, left, right}, scope), do: {:eq, resolve(left, scope), resolve(right, scope)}
  def resolve({:field, base, field}, scope), do: {:field, resolve(base, scope), field}
  def resolve({:value, value}, _scope), do: {:value, value}
  def resolve({:ref, ref}, _scope), do: {:ref, ref}

  def split_main_condition(scope) do
    scope.query_conditions
    |> resolve(scope)
    |> do_split_main_condition()
  end

  defp do_split_main_condition(true) do
    {[], true}
  end

  defp do_split_main_condition({:eq, {:field, {:ref, :root}, field}, {:value, value}}) do
    {[{field, value}], true}
  end

  defp do_split_main_condition({:all_of, conditions}) do
    case do_split_all_of(conditions, [], conditions) do
      {main_condition, other_conditions} -> {main_condition, {:all_of, other_conditions}}
    end
  end

  defp do_split_all_of([], _acc, original) do
    {[], original}
  end

  defp do_split_all_of(
         [{:eq, {:field, {:ref, :root}, field}, {:value, value}} | rest],
         acc,
         _original
       )
       when is_atom(field) do
    {[{field, value}], Enum.reverse(acc, rest)}
  end

  defp do_split_all_of([elem | rest], acc, original) do
    do_split_all_of(rest, [elem | acc], original)
  end
end
