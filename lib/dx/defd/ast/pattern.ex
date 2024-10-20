defmodule Dx.Defd.Ast.Pattern do
  @moduledoc false

  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.Loader
  alias Dx.Defd.Ast.State

  import Dx.Defd.Ast.Guards

  @doc """
  Returns internal representation of a pattern, consisting of deeply nested maps.
  The purpose is to merge multiple patterns to represent their data requirements.

  This is used in
  - `load_required_scopes/3` to load scopes required to match the pattern(s) (compile time)
  - `mark_finalized_vars/3` to mark variables containing such loaded scopes (compile time)
  - `Dx.Defd.Runtime.fetch/3` to (pre)load associations and scopes required to match the pattern(s)

  ## Arguments

  - `vars` (optional) can be accessed fields (dot syntax) in guards (see `quoted_guard_data_reqs/2`)

  ## Examples

  iex> quote do
  ...>   [%{status: :ok, created_by: {:other, list}}]
  ...> end
  ...> |> quoted_data_req(:preloads)
  %{__list__:
    %{
      0 => %{
        status: %{},
        created_by: %{}
      }
    }
  }

  iex> quote do
  ...>   [%{status: :ok, created_by: {:other, list}}]
  ...> end
  ...> |> quoted_data_req(:scopes)
  %{
    __list__: %{
      0 => %{
        status: %{},
        created_by: %{
          {:__tuple__, 2} => %{
            0 => %{},
            1 => %{}
          }
        }
      }
    }
  }
  """
  def quoted_data_req(ast, mode, vars \\ %{})

  def quoted_data_req({elem_0, elem_1}, mode, vars) do
    maybe_add_elems({:__tuple__, 2}, [elem_0, elem_1], mode, vars)
  end

  def quoted_data_req({:{}, _meta, tuple_elems}, mode, vars) do
    maybe_add_elems({:__tuple__, length(tuple_elems)}, tuple_elems, mode, vars)
  end

  def quoted_data_req(list, mode, vars) when is_list(list) do
    maybe_add_elems(:__list__, list, mode, vars)
  end

  # struct
  def quoted_data_req({:%, _meta, [_type, map]}, mode, vars) do
    quoted_data_req(map, mode, vars)
  end

  def quoted_data_req({:%{}, _meta, pairs}, :preloads, vars) do
    Enum.reduce(pairs, %{}, fn
      {k, v}, acc when is_atom(k) ->
        Map.put(acc, k, quoted_data_req(v, :preloads, vars))

      {k, v}, acc ->
        key_req = quoted_data_req(k, :preloads, vars)

        acc
        |> Map.update(:__keys__, key_req, &Dx.Util.deep_merge(&1, key_req))
        |> Map.put(key_req, quoted_data_req(v, :preloads, vars))
    end)
  end

  def quoted_data_req({:%{}, _meta, pairs}, :scopes, vars) do
    Map.new(pairs, fn
      {k, v} when is_atom(k) -> {k, quoted_data_req(v, :scopes, vars)}
      {k, v} -> {quoted_data_req(k, :scopes, vars), quoted_data_req(v, :scopes, vars)}
    end)
  end

  def quoted_data_req(var, _mode, vars) when is_var(var) do
    Map.get(vars, Ast.var_id(var), %{})
  end

  def quoted_data_req({:^, _meta, _}, :scopes, _vars) do
    %{__load__: %{}}
  end

  def quoted_data_req(_other, _mode, _vars) do
    %{}
  end

  defp maybe_add_elems(key, elems, mode, vars) do
    maybe_add_nested(%{}, key, mode, maybe_add_elems(elems, mode, vars))
  end

  defp maybe_add_elems(list, mode, vars) do
    list
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {elem, index}, acc ->
      maybe_add_nested(acc, index, mode, quoted_data_req(elem, mode, vars))
    end)
  end

  defp maybe_add_nested(map, _key, :preloads, val) when val == %{}, do: map
  defp maybe_add_nested(map, key, _mode, val), do: Map.put(map, key, val)

  @doc """
  Collected dot syntax chains in guards, returned as deeply nested map,
  like `quoted_data_req/3` but with variables at the root level.

  ## Examples

  iex> quote do
  ...>   var when var.field.nested_field
  ...> end
  ...> |> quoted_guard_data_reqs()
  %{
    {:var, [], __MODULE__} => %{
      __load__: %{},
      field: %{
        nested_field: %{}
      }
    }
  }
  """
  def quoted_guard_data_reqs(ast, acc \\ %{})

  def quoted_guard_data_reqs(ast, acc) do
    Macro.prewalk(ast, acc, fn
      var, acc when is_var(var) ->
        acc = Dx.Util.Map.put_in_create(acc, [Ast.var_id(var), :__load__], %{})

        {var, acc}

      {{:., _meta, [_module, fun_name]}, meta2, args} = fun, acc
      when is_atom(fun_name) and is_list(args) ->
        # Access.get/2
        if meta2[:no_parens] do
          acc =
            case quoted_access_data_req(fun) do
              {:ok, var, fields} ->
                data_req = Dx.Util.Map.put_in_create(%{}, [var | :lists.reverse(fields)], %{})
                Dx.Util.deep_merge(acc, data_req)

              :error ->
                acc
            end

          {fun, acc}
        else
          {fun, acc}
        end

      ast, acc ->
        {ast, acc}
    end)
    |> elem(1)
  end

  defp quoted_access_data_req({{:., _meta2, [base, field]}, meta, []}) do
    if meta[:no_parens] == true do
      case quoted_access_data_req(base) do
        {:ok, var} -> {:ok, var, [field]}
        {:ok, var, fields} -> {:ok, var, [field | fields]}
      end
    else
      :error
    end
  end

  defp quoted_access_data_req(var) when is_var(var) do
    {:ok, Ast.var_id(var)}
  end

  defp quoted_access_data_req(_other) do
    :error
  end

  @doc """
  Loads scopes required to match one or multiple patterns.

  See `quoted_data_req/3` for more info.
  """
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

  @doc """
  Marks variables bound in a pattern as finalized, which were already loaded via `load_required_scopes/3`
  """
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
    Macro.prewalk(pattern, state, fn
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

  @doc """
  Marks vars bound in a pattern as finalized, which are equal or part of already finalized input vars
  """
  def mark_finalized_input_vars({pattern, state}, input_ast) do
    mark_finalized_input_vars(pattern, input_ast, state)
  end

  def mark_finalized_input_vars(pattern, input_ast, state) when is_var(input_ast) do
    if Ast.var_id(input_ast) in state.finalized_vars do
      Macro.prewalk(pattern, state, fn
        var, state when is_var(var) -> {var, State.mark_var_as_finalized(var, state)}
        other, state -> {other, state}
      end)
    else
      {pattern, state}
    end
  end

  def mark_finalized_input_vars(pattern, input_ast, state) when is_var(pattern) do
    {_, all_vars_finalized?} =
      Macro.prewalk(input_ast, true, fn
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
    Macro.prewalk(pattern, state, fn
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
end
