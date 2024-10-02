defmodule Dx.Defd.Block do
  @moduledoc false

  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.Loader
  alias Dx.Defd.Compiler

  def normalize({:__block__, meta, lines}, state) do
    case normalize_block_body(lines, state) do
      {[ast], state} -> {ast, state}
      {lines, state} -> {{:__block__, meta, lines}, state}
    end
  end

  def normalize({:=, meta, [pattern, right]}, state) do
    {right, state} = Compiler.normalize(right, state)
    right = Ast.unwrap(right)

    state = Map.update!(state, :args, &Ast.collect_vars(pattern, &1))
    data_req = Dx.Defd.Case.quoted_data_req(pattern)

    if data_req == %{} do
      var = Ast.var_id(pattern)
      state = Loader.add_assign(state, var, right)
      ast = {:__block__, [], []}

      {ast, state}
    else
      {{:ok, var}, state} =
        quote do
          Dx.Defd.Runtime.fetch(
            unquote(right),
            unquote(Macro.escape(data_req)),
            unquote(state.eval_var)
          )
        end
        |> Loader.add(state)

      ast = {:ok, {:=, meta, [pattern, var]}}

      {ast, state}
    end
  end

  def normalize(ast, state) do
    Compiler.normalize(ast, state)
  end

  defp normalize_block_body([], state) do
    {[], state}
  end

  defp normalize_block_body([ast], state) do
    {ast, new_state} = normalize(ast, state)

    {[ast], new_state}
  end

  defp normalize_block_body([ast | rest], state) do
    {ast, new_state} = normalize(ast, state)

    # remove {:ok, ...} for every line that's not the last in the block
    ast = maybe_unwrap(ast)

    new_vars = MapSet.difference(new_state.args, state.args)

    {rest, state} =
      if new_vars == %{} do
        normalize_block_body(rest, new_state)
      else
        case normalize_block_body(rest, new_state) do
          {[ast], state} ->
            case Loader.ensure_vars_loaded(ast, new_vars, state) do
              {ast, state} -> {[ast], state}
            end

          {lines, state} ->
            ast = to_block(lines, state)

            case Loader.ensure_vars_loaded(ast, new_vars, state) do
              {{:__block__, _meta, lines}, state} -> {lines, state}
              {ast, state} -> {[ast], state}
            end
        end
      end

    {[ast | rest], state}
  end

  defp maybe_unwrap({:ok, ast}), do: ast
  defp maybe_unwrap(ast), do: ast

  defp to_block([{_, meta, _} | _rest] = lines, state) do
    {:__block__, [line: meta[:line] || state.line], lines}
  end

  defp to_block([{:ok, {_, meta, _}} | _rest] = lines, state) do
    {:__block__, [line: meta[:line] || state.line], lines}
  end

  defp to_block(lines, state) do
    {:__block__, [line: state.line], lines}
  end
end
