defmodule Dx.Defd_.Compiler do
  @moduledoc false

  alias Dx.Defd.Ast

  def __compile__(%Macro.Env{module: module}, moduledx_, fun_infos) do
    existing_clauses =
      case Module.get_definition(module, {:__dx_fun_info, 2}) do
        {:v1, :def, _meta, clauses} ->
          Module.delete_definition(module, {:__dx_fun_info, 2})

          Enum.map(clauses, fn
            {_meta, args, [], ast} ->
              quote do
                def __dx_fun_info(unquote_splicing(args)) do
                  unquote(ast)
                end
              end

            {_meta, args, guards, ast} ->
              quote do
                def __dx_fun_info(unquote_splicing(args)) when unquote_splicing(guards) do
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
            def __dx_fun_info(unquote(name), unquote(arity)) do
              unquote(Macro.escape(fun_info))
            end
          end
          |> List.wrap()

        _else ->
          []
      end)

    fallback_clause =
      quote do
        def __dx_fun_info(_fun_name, _arity) do
          unquote(Macro.escape(moduledx_))
        end
      end

    (annotated_clauses ++ existing_clauses ++ [fallback_clause])
    |> Ast.block()
  end
end
