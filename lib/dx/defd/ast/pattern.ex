defmodule Dx.Defd.Ast.Pattern do
  @moduledoc false

  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.Loader
  alias Dx.Defd.Ast.State
  alias Dx.Defd.Case

  import Dx.Defd.Ast.Guards

  def data_req_from_clauses([], acc) do
    acc
  end

  def data_req_from_clauses(
        [{:->, _meta, [[{:when, _meta2, [pattern | guards]}], _result]} | tail],
        acc
      ) do
    vars = Case.quoted_guard_data_reqs(guards, %{})
    data_req = quoted_data_req(pattern, vars)
    acc = Dx.Util.deep_merge(acc, data_req)
    data_req_from_clauses(tail, acc)
  end

  def data_req_from_clauses([{:->, _meta, [[pattern], _result]} | tail], acc) do
    data_req = quoted_data_req(pattern, %{})
    acc = Dx.Util.deep_merge(acc, data_req)
    data_req_from_clauses(tail, acc)
  end

  def quoted_data_req(ast, vars \\ %{})

  def quoted_data_req({elem_0, elem_1}, vars) do
    add_elems({:__tuple__, 2}, [elem_0, elem_1], vars)
  end

  def quoted_data_req({:{}, _meta, tuple_elems}, vars) do
    add_elems({:__tuple__, length(tuple_elems)}, tuple_elems, vars)
  end

  def quoted_data_req(list, vars) when is_list(list) do
    add_elems(:__list__, list, vars)
  end

  # struct
  def quoted_data_req({:%, _meta, [_type, map]}, vars) do
    quoted_data_req(map, vars)
  end

  def quoted_data_req({:%{}, _meta, pairs}, vars) do
    Map.new(pairs, fn
      {k, v} when is_atom(k) -> {k, quoted_data_req(v, vars)}
      {k, v} -> {quoted_data_req(k, vars), quoted_data_req(v, vars)}
    end)
  end

  def quoted_data_req(var, vars) when is_var(var) do
    Map.get(vars, Ast.var_id(var), %{})
  end

  def quoted_data_req({:^, _meta, _}, _vars) do
    %{__load__: %{}}
  end

  def quoted_data_req(_other, _vars) do
    %{}
  end

  defp add_elems(key, elems, vars) do
    add_nested(%{}, key, add_elems(elems, vars))
  end

  defp add_elems(list, vars) do
    list
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {elem, index}, acc ->
      add_nested(acc, index, quoted_data_req(elem, vars))
    end)
  end

  defp add_nested(map, key, val), do: Map.put(map, key, val)

  def load_required_scopes({input_ast, state}, data_reqs) do
    load_required_scopes(input_ast, data_reqs, state)
  end

  def load_required_scopes(ast, data_reqs, state) when data_reqs == %{} do
    {ast, state}
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

  def load_required_scopes({:%{}, meta, pairs} = ast, data_reqs, state) do
    if is_map(data_reqs) do
      {pairs, state} =
        Enum.map_reduce(pairs, state, fn {key_ast, val_ast}, state ->
          val_reqs = Map.get(data_reqs, key_ast, %{})
          {val_ast, state} = load_required_scopes(val_ast, val_reqs, state)
          {{key_ast, val_ast}, state}
        end)

      {{:%{}, meta, pairs}, state}
    else
      {ast, state}
    end
  end

  def load_required_scopes(input_ast, remaining_data_reqs, state) do
    if is_var(input_ast) and Ast.var_id(input_ast) in state.finalized_vars do
      {input_ast, state}
    else
      {{:ok, var}, state} =
        quote do
          Dx.Defd.Runtime.fetch(
            unquote(input_ast),
            unquote(Macro.escape(remaining_data_reqs)),
            unquote(state.eval_var)
          )
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

  def mark_finalized_vars({pattern, state}, data_reqs) do
    mark_finalized_vars(pattern, data_reqs, state)
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
