defmodule Dx.Scope.Case do
  @moduledoc false

  alias Dx.Defd.Ast
  alias Dx.Scope.Compiler

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
    {condition, state} = Compiler.normalize(condition, state)
    {then_ast, state} = Compiler.normalize(then_ast, state)
    fallback = Compiler.generate_fallback(ast, meta, state)

    quote do
      {:and, unquote(condition), unquote(then_ast), unquote(fallback)}
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
    {condition, state} = Compiler.normalize(condition, state)
    {then_ast, state} = Compiler.normalize(then_ast, state)
    fallback = Compiler.generate_fallback(ast, meta, state)

    quote do
      {:&&, unquote(condition), unquote(then_ast), unquote(fallback)}
    end
    |> with_state(state)
  end

  def normalize(other, state) do
    meta = Ast.closest_meta(other)
    fallback = Compiler.generate_fallback(other, meta, state)

    {:error, fallback}
    |> with_state(state)
  end

  ## Helpers

  @compile {:inline, with_state: 2}
  defp with_state(ast, state), do: {ast, state}
end
