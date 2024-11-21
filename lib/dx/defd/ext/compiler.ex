defmodule Dx.Defd.Ext.Compiler do
  @moduledoc false

  alias Dx.Defd.Ast

  def __compile__(%Macro.Env{module: module}, fun_infos) do
    existing_clauses =
      case Module.get_definition(module, {:__fun_info, 2}) do
        {:v1, :def, _meta, clauses} ->
          Module.delete_definition(module, {:__fun_info, 2})

          Enum.map(clauses, fn
            {_meta, args, [], ast} ->
              quote do
                def __fun_info(unquote_splicing(args)) do
                  unquote(ast)
                end
              end

            {_meta, args, guards, ast} ->
              quote do
                def __fun_info(unquote_splicing(args)) when unquote_splicing(guards) do
                  unquote(ast)
                end
              end
          end)

        _other ->
          []
      end

    annotated_clauses =
      Enum.flat_map(fun_infos, fn
        {{name, arity}, %{fun_info: fun_info}} ->
          quote do
            def __fun_info(unquote(name), unquote(arity)) do
              unquote(Macro.escape(fun_info))
            end
          end
          |> List.wrap()

        _else ->
          []
      end)

    (annotated_clauses ++ existing_clauses)
    |> Ast.block()
  end
end
