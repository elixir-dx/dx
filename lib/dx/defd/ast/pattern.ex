defmodule Dx.Defd.Ast.Pattern do
  @moduledoc false

  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.Loader
  alias Dx.Defd.Ast.State

  import Dx.Defd.Ast.Guards

  def load_required_scopes({input_ast, state}, data_reqs) do
    load_required_scopes(input_ast, data_reqs, state)
  end

  def load_required_scopes(list, data_reqs, state) when is_list(list) do
    if elem_reqs = data_reqs[:__list__] do
      load_required_scopes_in_list(list, elem_reqs, state)
    else
      {list, state}
    end
  end

  def load_required_scopes({elem0, elem1} = ast, data_reqs, state) do
    if elem_reqs = data_reqs[{:__tuple__, 2}] do
      {[elem0, elem1], state} = load_required_scopes_in_list([elem0, elem1], elem_reqs, state)

      {{elem0, elem1}, state}
    else
      {ast, state}
    end
  end

  def load_required_scopes({:{}, meta, elems} = ast, data_reqs, state) do
    if elem_reqs = data_reqs[{:__tuple__, length(elems)}] do
      {elems, state} = load_required_scopes_in_list(elems, elem_reqs, state)

      {{:{}, meta, elems}, state}
    else
      {ast, state}
    end
  end

  def load_required_scopes(input_ast, _data_reqs, state) do
    if is_var(input_ast) and Ast.var_id(input_ast) in state.finalized_vars do
      {input_ast, state}
    else
      {{:ok, var}, state} =
        quote do
          Dx.Defd.Runtime.load_scopes(unquote(input_ast), unquote(state.eval_var))
        end
        |> Loader.add(state)

      {var, state}
    end
  end

  defp load_required_scopes_in_list(list, data_reqs_by_index, state) do
    list
    |> Enum.with_index()
    |> Enum.map_reduce(state, fn {elem, index}, state ->
      data_reqs = Map.get(data_reqs_by_index, index, %{})
      load_required_scopes(elem, data_reqs, state)
    end)
  end

  def mark_finalized_vars(pattern, data_reqs, state) when data_reqs == %{} do
    {pattern, state}
  end

  def mark_finalized_vars(list, data_reqs, state) when is_list(list) do
    if elem_reqs = data_reqs[:__list__] do
      mark_finalized_vars_in_list(list, elem_reqs, state)
    else
      {list, state}
    end
  end

  def mark_finalized_vars(tuple, data_reqs, state) when is_tuple(tuple) do
    if elem_reqs = data_reqs[{:__tuple__, tuple_size(tuple)}] do
      {list, state} =
        tuple
        |> Tuple.to_list()
        |> mark_finalized_vars_in_list(elem_reqs, state)

      {List.to_tuple(list), state}
    else
      {tuple, state}
    end
  end

  def mark_finalized_vars(pattern, _data_reqs, state) do
    prewalk(pattern, state, fn
      var, state when is_var(var) -> State.mark_var_as_finalized(var, state)
      other, state -> {other, state}
    end)
  end

  defp mark_finalized_vars_in_list(list, data_reqs_by_index, state) do
    list
    |> Enum.with_index()
    |> Enum.map_reduce(state, fn {elem, index}, state ->
      data_reqs = Map.get(data_reqs_by_index, index, %{})
      mark_finalized_vars(elem, data_reqs, state)
    end)
  end

  @doc "Marks vars in pattern as finalized based on already finalized input vars in subject"
  def mark_finalized_input_vars({pattern, state}, input_ast) do
    mark_finalized_input_vars(pattern, input_ast, state)
  end

  def mark_finalized_input_vars(pattern, input_ast, state) when is_var(input_ast) do
    if Ast.var_id(input_ast) in state.finalized_vars do
      prewalk(pattern, state, fn
        var, state when is_var(var) -> {var, State.mark_var_as_finalized(var, state)}
        other, state -> {other, state}
      end)
    else
      {pattern, state}
    end
  end

  def mark_finalized_input_vars(pattern, input_ast, state) when is_var(pattern) do
    {_, all_vars_finalized?} =
      prewalk(input_ast, true, fn
        var, result when is_var(var) -> {var, result and State.var_finalized?(var, state)}
        other, result -> {other, result}
      end)

    if all_vars_finalized? do
      state = State.mark_var_as_finalized(pattern, state)
      {pattern, state}
    else
      {pattern, state}
    end
  end

  def mark_finalized_input_vars(list, input_ast, state)
      when is_list(list) and is_list(input_ast) do
    mark_finalized_input_vars_in_list(list, input_ast, state)
  end

  def mark_finalized_input_vars(pattern, _input_ast, state) do
    prewalk(pattern, state, fn
      var, state when is_var(var) -> {var, State.mark_var_as_finalized(var, state)}
      other, state -> {other, state}
    end)
  end

  defp mark_finalized_input_vars_in_list(list, input_ast, state) do
    list
    |> Enum.zip(input_ast)
    |> Enum.map_reduce(state, fn {pattern_elem, input_elem}, state ->
      mark_finalized_input_vars(pattern_elem, input_elem, state)
    end)
  end

  # Macro.prewalk/3 with special treatment for pinned variables
  defp prewalk(ast, acc, fun) do
    traverse(ast, acc, fun, fn x, a -> {x, a} end)
  end

  defp traverse(ast, acc, pre, post) do
    {ast, acc} = pre.(ast, acc)
    do_traverse(ast, acc, pre, post)
  end

  defp do_traverse({form, meta, args}, acc, pre, post) when is_atom(form) do
    {args, acc} = do_traverse_args(args, acc, pre, post)
    post.({form, meta, args}, acc)
  end

  defp do_traverse({form, meta, args}, acc, pre, post) do
    {form, acc} = pre.(form, acc)
    {form, acc} = do_traverse(form, acc, pre, post)
    {args, acc} = do_traverse_args(args, acc, pre, post)
    post.({form, meta, args}, acc)
  end

  defp do_traverse({left, right}, acc, pre, post) do
    {left, acc} = pre.(left, acc)
    {left, acc} = do_traverse(left, acc, pre, post)
    {right, acc} = pre.(right, acc)
    {right, acc} = do_traverse(right, acc, pre, post)
    post.({left, right}, acc)
  end

  defp do_traverse(list, acc, pre, post) when is_list(list) do
    {list, acc} = do_traverse_args(list, acc, pre, post)
    post.(list, acc)
  end

  defp do_traverse(x, acc, _pre, post) do
    post.(x, acc)
  end

  defp do_traverse_args(args, acc, _pre, _post) when is_atom(args) do
    {args, acc}
  end

  defp do_traverse_args(args, acc, pre, post) when is_list(args) do
    :lists.mapfoldl(
      fn x, acc ->
        {x, acc} = pre.(x, acc)
        do_traverse(x, acc, pre, post)
      end,
      acc,
      args
    )
  end
end
