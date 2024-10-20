defmodule Dx.Defd.Case do
  @moduledoc false

  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.Loader
  alias Dx.Defd.Ast.Pattern
  alias Dx.Defd.Compiler

  def normalize({:case, meta, [subject, [do: clauses]]}, state) do
    data_req = data_req_from_clauses(clauses, :preloads)
    scope_data_req = data_req_from_clauses(clauses, :scopes)

    {subject, state} = Compiler.normalize(subject, state)

    {subject, state} =
      case subject do
        {:ok, subject} ->
          {subject, state}

        loader_ast ->
          {{:ok, var}, state} = Loader.add(loader_ast, state)

          {var, state}
      end
      |> Pattern.load_required_scopes(scope_data_req)

    {clauses, state} = normalize_clauses(clauses, data_req, subject, state)

    ast =
      if data_req == %{} do
        # nothing to load in any pattern
        case to_ok_clauses(clauses) do
          {:ok, clauses} -> {:ok, {:case, meta, [subject, [do: clauses]]}}
          :error -> {:case, meta, [subject, [do: clauses]]}
        end
      else
        # ensure data requirements are preloaded
        subject_var = Macro.unique_var(:subject, __MODULE__)

        case_ast =
          case to_ok_clauses(clauses) do
            {:ok, clauses} -> {:ok, {:case, meta, [subject_var, [do: clauses]]}}
            :error -> {:case, meta, [subject_var, [do: clauses]]}
          end

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

  def normalize_clauses(clauses, data_reqs, subject, state) do
    Enum.map_reduce(clauses, state, &normalize_clause(&1, data_reqs, subject, &2))
  end

  def normalize_clause(
        {:->, meta, [[{:when, meta2, [pattern | guards]}], ast]},
        data_reqs,
        subject,
        state
      ) do
    {pattern, state} =
      pattern
      |> ensure_carets_loaded(state)
      |> Pattern.mark_finalized_vars(data_reqs)
      |> Pattern.mark_finalized_input_vars(subject)

    guards = guards |> normalize_guards()

    {ast, state} =
      Ast.with_root_args(pattern, state, fn state ->
        Compiler.normalize(ast, state)
      end)

    ast = {:->, meta, [[{:when, meta2, [pattern | guards]}], ast]}

    {ast, state}
  end

  def normalize_clause({:->, meta, [[pattern], ast]}, data_reqs, subject, state) do
    {pattern, state} =
      pattern
      |> ensure_carets_loaded(state)
      |> Pattern.mark_finalized_vars(data_reqs)
      |> Pattern.mark_finalized_input_vars(subject)

    {ast, state} =
      Ast.with_root_args(pattern, state, fn state ->
        Compiler.normalize(ast, state)
      end)

    ast = {:->, meta, [[pattern], ast]}

    {ast, state}
  end

  defp to_ok_clauses(clauses, result \\ {:ok, []})

  defp to_ok_clauses([], {:ok, result}) do
    {:ok, :lists.reverse(result)}
  end

  defp to_ok_clauses([{:->, meta, [[pattern], {:ok, ast}]} | rest], {:ok, result}) do
    to_ok_clauses(rest, {:ok, [{:->, meta, [[pattern], ast]} | result]})
  end

  defp to_ok_clauses(_, _) do
    :error
  end

  defp ensure_carets_loaded(pattern, state) do
    Macro.prewalk(pattern, state, fn
      {:^, meta, args}, state ->
        {args, state} = Ast.load_scopes(args, state)

        {{:^, meta, args}, state}

      other, state ->
        {other, state}
    end)
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

  def data_req_from_clauses(pattern_ast, mode, acc \\ %{})

  def data_req_from_clauses([], _mode, acc) do
    acc
  end

  def data_req_from_clauses(
        [{:->, _meta, [[{:when, _meta2, [pattern | guards]}], _result]} | tail],
        mode,
        acc
      ) do
    vars = Pattern.quoted_guard_data_reqs(guards)
    data_req = Pattern.quoted_data_req(pattern, mode, vars)
    acc = Dx.Util.deep_merge(acc, data_req)
    data_req_from_clauses(tail, mode, acc)
  end

  def data_req_from_clauses([{:->, _meta, [[pattern], _result]} | tail], mode, acc) do
    data_req = Pattern.quoted_data_req(pattern, mode)
    acc = Dx.Util.deep_merge(acc, data_req)
    data_req_from_clauses(tail, mode, acc)
  end
end
