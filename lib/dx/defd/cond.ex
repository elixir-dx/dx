defmodule Dx.Defd.Cond do
  @moduledoc false

  alias Dx.Defd.Ast.Loader
  alias Dx.Defd.Compiler

  def normalize({:cond, _meta, [[do: clauses]]}, state) do
    {{:cond, meta, [[do: clauses]]}, new_state} = orig_result = normalize_clauses(clauses, state)

    Enum.reduce_while(clauses, [], fn
      {:->, meta, [[condition], {:ok, clause_ast}]}, acc ->
        {:cont, [{:->, meta, [[condition], clause_ast]} | acc]}

      _else, _acc ->
        {:halt, :error}
    end)
    |> case do
      :error -> orig_result
      ok_clauses -> {{:ok, {:cond, meta, [[do: ok_clauses]]}}, new_state}
    end
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
    {clause_ast, state} = normalize_clause(clause, state)

    case do_normalize_clauses(rest, state) do
      {{:cond, meta, [[do: clauses]]}, state} ->
        {:cond, meta, [[do: [clause_ast | clauses]]]}
        |> with_state(state)

      {clauses_ast, state} ->
        {:cond, [],
         [
           [
             do: [
               clause_ast,
               {:->, [], [[true], clauses_ast]}
             ]
           ]
         ]}
        |> with_state(state)
    end
  end

  defp do_normalize_clauses(clauses, state) do
    Loader.with_new_loaders_loaded(state, fn state ->
      normalize_clauses(clauses, state)
    end)
  end

  def normalize_clause({:->, meta, [[condition], ast]}, state) do
    {condition, state} =
      case Compiler.normalize(condition, state) do
        {{:ok, condition}, state} ->
          {condition, state}

        {loader, state} ->
          {{:ok, condition}, state} = Loader.add(loader, state)
          {condition, state}
      end

    {ast, state} =
      Loader.with_new_loaders_loaded(state, fn state ->
        Compiler.normalize(ast, state)
      end)

    {:->, meta, [[condition], ast]}
    |> with_state(state)
  end

  ## Helpers

  @compile {:inline, with_state: 2}
  defp with_state(ast, state), do: {ast, state}
end
