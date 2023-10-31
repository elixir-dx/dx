defmodule Dx.Defd.Block do
  alias Dx.Defd.Ast
  alias Dx.Defd.Compiler
  alias Dx.Util

  def normalize({:=, meta, [pattern, right]}, state) do
    {right, state} = Compiler.normalize(right, state)
    right = Ast.unwrap(right)

    state = Map.update!(state, :args, &Ast.collect_vars(pattern, &1))
    data_req = Dx.Defd.Case.quoted_data_req(pattern)

    {right, state} =
      if data_req == %{} do
        {right, state}
      else
        loader_ast =
          quote do
            Dx.Defd.Util.fetch(
              unquote(right),
              unquote(Macro.escape(data_req)),
              unquote(state.eval_var)
            )
          end

        state =
          Map.update!(state, :data_reqs, fn data_reqs ->
            Map.put_new(data_reqs, loader_ast, Macro.unique_var(:data, __MODULE__))
          end)

        var = state.data_reqs[loader_ast]

        {var, state}
      end

    ast = {:ok, {:=, meta, [pattern, right]}}

    {ast, state}
  end

  def normalize({:__block__, meta, lines}, state) do
    case normalize_block_body(lines, state) do
      {[ast], state} -> {ast, state}
      {lines, state} -> {{:__block__, meta, lines}, state}
    end
  end

  defp normalize_block_body([], state) do
    {[], state}
  end

  defp normalize_block_body([ast], state) do
    {ast, new_state} = Compiler.normalize(ast, state)

    {[ast], new_state}
  end

  defp normalize_block_body([ast | rest], state) do
    {ast, new_state} = Compiler.normalize(ast, state)

    # remove {:ok, ...} for every line that's not the last in the block
    ast = maybe_unwrap(ast)

    new_vars = Util.Map.subtract(new_state.args, state.args)

    {rest, state} =
      if new_vars == %{} do
        normalize_block_body(rest, new_state)
      else
        case normalize_block_body(rest, new_state) do
          {[ast], state} ->
            case Ast.prepend_data_reqs_in({ast, state}, new_vars) do
              {ast, state} -> {[ast], state}
            end

          {lines, state} ->
            ast = to_block(lines, state)

            case Ast.prepend_data_reqs_in({ast, state}, new_vars) do
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
