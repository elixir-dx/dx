defmodule Dx.Defd.Cond do
  alias Dx.Defd.Ast
  alias Dx.Defd.Compiler

  def normalize({:cond, _meta, [[do: clauses]]}, state) do
    normalize_clauses(clauses, state)
  end

  def normalize({:cond, meta, _args}, state) do
    Compiler.compile_error!(meta, state, """
    Invalid case syntax. Add a do .. end block like the following:

    cond do
      condition -> result
      ...
    end
    """)
  end

  defp normalize_clauses([clause], state) do
    {{:->, clause_meta, _} = clause, state} = normalize_clause(clause, state)

    {:cond, clause_meta, [[do: [clause]]]}
    |> with_state(state)
  end

  defp normalize_clauses([clause | rest], state) do
    {{:->, clause_meta, [[condition], clause_ast]}, updated_state} =
      normalize_clause(clause, state)

    new_data_reqs =
      Enum.reject(updated_state.data_reqs, fn {loader_ast, _data_var} ->
        Map.has_key?(state.data_reqs, loader_ast)
      end)
      |> Map.new()

    case {Enum.empty?(new_data_reqs), normalize_clauses(rest, updated_state)} do
      {true, {{:cond, meta, [[do: clauses]]}, updated_state}} ->
        {:cond, meta,
         [
           [
             do: [
               {:->, clause_meta, [[condition], clause_ast]}
               | clauses
             ]
           ]
         ]}
        |> with_state(updated_state)

      {_, {rest_ast, updated_state}} ->
        updated_state = %{updated_state | data_reqs: new_data_reqs}

        {clause_ast, updated_state} =
          {:cond, clause_meta,
           [
             [
               do: [
                 {:->, clause_meta, [[condition], clause_ast]},
                 flatten_fallback({:->, clause_meta, [[true], rest_ast]})
               ]
             ]
           ]}
          |> Ast.ensure_all_loaded(updated_state)

        clause_ast
        |> with_state(%{updated_state | data_reqs: state.data_reqs})
    end
  end

  def normalize_clause({:->, meta, [[condition], ast]}, state) do
    {{:ok, condition}, state} = Compiler.normalize(condition, state)

    {ast, state} =
      Ast.with_new_loaders_loaded(state, fn state ->
        Compiler.normalize(ast, state)
      end)

    {:->, meta, [[condition], ast]}
    |> with_state(state)
  end

  defp flatten_fallback(
         {:->, _, [[true], {:cond, _, [[do: [{:->, _, [[true], _]} = inner_fallback]]]}]}
       ) do
    inner_fallback
  end

  defp flatten_fallback(ast), do: ast

  ## Helpers

  @compile {:inline, with_state: 2}
  defp with_state(ast, state), do: {ast, state}
end
