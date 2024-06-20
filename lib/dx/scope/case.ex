defmodule Dx.Scope.Case do
  @moduledoc false

  alias Dx.Defd.Ast

  # and/2
  def normalize(
        {:case, meta,
         [
           condition,
           [
             do: [
               {:->, _, [[false], false]},
               {:->, _, [[true], then_ast]}
             ]
           ]
         ]} = ast,
        state
      ) do
    {condition, state} = condition |> Dx.Scope.Compiler.normalize(state) |> dbg()
    {then_ast, state} = Dx.Scope.Compiler.normalize(then_ast, state)

    {fun, _state} =
      Ast.with_args_no_loaders!(state.scope_args, state, fn state ->
        {:fn, meta, [{:->, meta, [state.scope_args ++ [state.eval_var], ast]}]}
        |> Dx.Defd.Compiler.normalize_fn(false, state)
      end)

    quote do
      {:and, unquote(condition), unquote(then_ast), unquote(fun)}
    end
    |> with_state(state)
  end

  # &&/2
  def normalize(
        {:case, meta,
         [
           condition,
           [
             do: [
               {:->, _,
                [
                  [
                    {:when, _,
                     [
                       var,
                       {{:., _, [:erlang, :orelse]}, _,
                        [
                          {{:., _, [:erlang, :"=:="]}, _, [var, false]},
                          {{:., _, [:erlang, :"=:="]}, _, [var, nil]}
                        ]}
                     ]}
                  ],
                  var
                ]},
               {:->, _, [[{:_, _, Kernel}], then_ast]}
             ]
           ]
         ]} = ast,
        state
      ) do
    {condition, state} = Dx.Scope.Compiler.normalize(condition, state)
    {then_ast, state} = Dx.Scope.Compiler.normalize(then_ast, state)

    {fun, _state} =
      Ast.with_args_no_loaders!(state.scope_args, state, fn state ->
        {:fn, meta, [{:->, meta, [state.scope_args ++ [state.eval_var], ast]}]}
        |> Dx.Defd.Compiler.normalize_fn(false, state)
      end)

    quote do
      {:&&, unquote(condition), unquote(then_ast), unquote(fun)}
    end
    |> with_state(state)
  end

  def normalize(other, state) do
    meta = Ast.closest_meta(other)

    {fun, _state} =
      Ast.with_args_no_loaders!(state.scope_args, state, fn state ->
        {:fn, meta, [{:->, meta, [state.scope_args ++ [state.eval_var], other]}]}
        |> Dx.Defd.Compiler.normalize_fn(false, state)
      end)

    {:error, fun}
    |> with_state(state)
  end

  ## Helpers

  @compile {:inline, with_state: 2}
  defp with_state(ast, state), do: {ast, state}
end
