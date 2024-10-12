defmodule Dx.Defd.Case do
  @moduledoc false

  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.Loader
  alias Dx.Defd.Compiler

  import Dx.Defd.Ast.Guards

  def normalize({:case, meta, [subject, [do: clauses]]}, state) do
    data_req = data_req_from_clauses(clauses, %{})

    {subject, state} = Compiler.normalize(subject, state)

    {subject, state} =
      case subject do
        {:ok, subject} ->
          {subject, state}

        loader_ast ->
          {{:ok, var}, state} = Loader.add(loader_ast, state)

          {var, state}
      end
      |> Ast.load_scopes()

    {clauses, state} = normalize_clauses(clauses, state)

    ast =
      if data_req == %{} do
        # nothing to load in any pattern
        {:case, meta, [subject, [do: clauses]]}
      else
        # ensure data requirements are preloaded
        subject_var = Macro.unique_var(:subject, __MODULE__)
        case_ast = {:case, meta, [subject_var, [do: clauses]]}

        quote do
          case Dx.Defd.Runtime.fetch(
                 unquote(subject),
                 unquote(Macro.escape(data_req)),
                 unquote(state.eval_var)
               ) do
            {:ok, unquote(subject_var)} -> unquote(case_ast)
            other -> other
          end
        end
      end

    {ast, state}
  end

  def normalize({:case, meta, _args}, state) do
    Compiler.compile_error!(meta, state, """
    Invalid case syntax. Add a do .. end block like the following:

    case ... do
      pattern -> result
      ...
    end
    """)
  end

  def normalize_clauses(clauses, state) do
    Enum.map_reduce(clauses, state, &normalize_clause/2)
  end

  def normalize_clause({:->, meta, [[{:when, meta2, [pattern | guards]}], ast]}, state) do
    guards = guards |> normalize_guards()

    {ast, state} =
      Ast.with_root_args(pattern, state, fn state ->
        Compiler.normalize(ast, state)
      end)

    ast = {:->, meta, [[{:when, meta2, [pattern | guards]}], ast]}

    {ast, state}
  end

  def normalize_clause({:->, meta, [[pattern], ast]}, state) do
    {ast, state} =
      Ast.with_root_args(pattern, state, fn state ->
        Compiler.normalize(ast, state)
      end)

    ast = {:->, meta, [[pattern], ast]}

    {ast, state}
  end

  defp normalize_guards(guards) do
    Macro.postwalk(guards, fn
      # is_function/1
      {{:., _meta, [:erlang, :is_function]}, _meta2, [arg]} = check ->
        quote do: unquote(check) or is_struct(unquote(arg), Dx.Defd.Fn)

      # is_function/2
      {{:., _meta, [:erlang, :is_function]}, _meta2, [arg, arity]} = check ->
        quote do:
                unquote(check) or
                  (is_struct(unquote(arg), Dx.Defd.Fn) and
                     is_function(unquote(arg).fun, unquote(arity)))

      ast ->
        ast
    end)
  end

  defp data_req_from_clauses([], acc) do
    acc
  end

  defp data_req_from_clauses(
         [{:->, _meta, [[{:when, _meta2, [pattern | guards]}], _result]} | tail],
         acc
       ) do
    vars = quoted_guard_data_reqs(guards, %{})
    data_req = quoted_data_req(pattern, vars)
    acc = Dx.Util.deep_merge(acc, data_req)
    data_req_from_clauses(tail, acc)
  end

  defp data_req_from_clauses([{:->, _meta, [[pattern], _result]} | tail], acc) do
    data_req = quoted_data_req(pattern, %{})
    acc = Dx.Util.deep_merge(acc, data_req)
    data_req_from_clauses(tail, acc)
  end

  def quoted_guard_data_reqs(ast, acc) do
    Macro.prewalk(ast, acc, fn
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

  def quoted_access_data_req({{:., _meta2, [base, field]}, meta, []}) do
    if meta[:no_parens] == true do
      case quoted_access_data_req(base) do
        {:ok, var} -> {:ok, var, [field]}
        {:ok, var, fields} -> {:ok, var, [field | fields]}
      end
    else
      :error
    end
  end

  def quoted_access_data_req(var) when is_var(var) do
    {:ok, Ast.var_id(var)}
  end

  def quoted_access_data_req(_other) do
    :error
  end

  def quoted_data_req(ast, vars \\ %{})

  def quoted_data_req({elem_0, elem_1}, vars) do
    maybe_add_elems({:__tuple__, 2}, [elem_0, elem_1], vars)
  end

  def quoted_data_req({:{}, _meta, tuple_elems}, vars) do
    maybe_add_elems({:__tuple__, length(tuple_elems)}, tuple_elems, vars)
  end

  def quoted_data_req(list, vars) when is_list(list) do
    maybe_add_elems(:__list__, list, vars)
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

  def quoted_data_req(_other, _vars) do
    %{}
  end

  defp maybe_add_elems(key, elems, vars) do
    maybe_add_nested(%{}, key, maybe_add_elems(elems, vars))
  end

  defp maybe_add_elems(list, vars) do
    list
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {elem, index}, acc ->
      maybe_add_nested(acc, index, quoted_data_req(elem, vars))
    end)
  end

  defp maybe_add_nested(map, _key, val) when val == %{}, do: map
  defp maybe_add_nested(map, key, val), do: Map.put(map, key, val)
end
