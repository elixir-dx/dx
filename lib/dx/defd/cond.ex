defmodule Dx.Defd.Cond do
  @moduledoc false

  alias Dx.Defd.Ast.Loader
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

    new_loaders = Loader.subtract(updated_state.loaders, state.loaders)

    case {Enum.empty?(new_loaders), normalize_clauses(rest, updated_state)} do
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
        updated_state = %{updated_state | loaders: new_loaders}

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
          |> Loader.ensure_all_loaded(updated_state)

        clause_ast
        |> with_state(%{updated_state | loaders: state.loaders})
    end
  end

  def normalize_clause({:->, meta, [[condition], ast]}, state) do
    {{:ok, condition}, state} = Compiler.normalize(condition, state)

    {ast, state} =
      Loader.with_new_loaders_loaded(state, fn state ->
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
