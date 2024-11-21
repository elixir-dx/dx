defmodule Dx.Defd.Rewriter do
  @moduledoc false

  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.Loader
  alias Dx.Defd.Compiler
  alias Dx.Defd.Util

  # &Mod.fun/3
  def rewrite(
        {:&, meta, [{:/, [], [{{:., _meta2, [module, fun_name]}, _meta3, []}, arity]}]},
        rewriter,
        state
      ) do
    ast =
      cond do
        function_exported?(rewriter, fun_name, arity) ->
          args = Macro.generate_arguments(arity, __MODULE__)
          line = meta[:line] || state.line

          quote line: line do
            {:ok,
             fn unquote_splicing(args) ->
               unquote(rewriter).unquote(fun_name)(unquote_splicing(args))
             end}
          end

        true ->
          args = Macro.generate_arguments(arity, __MODULE__)
          line = meta[:line] || state.line

          quote line: line do
            {:ok,
             fn unquote_splicing(args) ->
               {:ok, unquote(module).unquote(fun_name)(unquote_splicing(args))}
             end}
          end
      end

    {ast, state}
  end

  # Mod.fun()
  def rewrite({{:., meta, [module, fun_name]}, meta2, orig_args}, rewriter, state) do
    arity = length(orig_args)
    fun_info = Util.fun_info(rewriter, fun_name, arity)

    {args, state} = Enum.map_reduce(orig_args, state, &Compiler.normalize/2)
    args_ok? = args_ok?(args, fun_info)

    maybe_warn_static(fun_info, meta, state)
    maybe_warn(args, fun_info, meta, state)

    {args, state} = prepare_args(args, fun_info, args_ok?, state)

    cond do
      fun_info.can_return_scope ->
        {{:., meta, [rewriter, fun_name]}, meta2, args}
        |> Loader.add(state)

      args_ok? ->
        {:ok, {{:., meta, [module, fun_name]}, meta2, args}}
        |> Ast.with_state(state)

      function_exported?(rewriter, fun_name, arity) ->
        {{:., meta, [rewriter, fun_name]}, meta2, args}
        |> Loader.add(state)

      # unknown function
      true ->
        {:ok, {{:., meta, [module, fun_name]}, meta2, args}}
        |> Ast.with_state(state)
    end
  end

  defp args_ok?(args, fun_info) do
    args
    |> Enum.zip(fun_info.args)
    |> Enum.all?(fn {arg, arg_info} ->
      cond do
        arg_info.fn -> Ast.ok?(arg, true)
        arg_info.final_args_fn -> Ast.final_args_ok?(arg, true)
        true -> Ast.ok?(arg)
      end
    end)
  end

  defp prepare_args(args, %{args: nil}, _args_ok?, state) do
    args = Enum.map(args, &Ast.unwrap_maybe_fn/1)
    {args, state}
  end

  defp prepare_args(args, fun_info, args_ok?, state) do
    args
    |> Enum.zip(fun_info.args)
    |> Enum.map_reduce(state, fn {arg, arg_info}, state ->
      # load
      {arg, state} =
        cond do
          arg_info.preload_scope and not fun_info.can_return_scope ->
            {{:ok, arg}, state} = Compiler.maybe_load_scope(arg, arg_info.atom_to_scope, state)

            {arg, state}

          arg_info.atom_to_scope ->
            arg =
              case arg do
                {:ok, atom} when is_atom(atom) -> quote do: {:ok, Dx.Scope.all(unquote(atom))}
                {:ok, other} -> quote do: {:ok, Dx.Scope.maybe_atom(unquote(other))}
              end

            {arg, state}

          true ->
            {arg, state}
        end

      # unwrap
      cond do
        fun_info.can_return_scope -> Ast.unwrap(arg)
        arg_info.fn && args_ok? -> Ast.unwrap_inner(arg)
        arg_info.fn -> Ast.unwrap_maybe_fn(arg)
        arg_info.final_args_fn && args_ok? -> Ast.unwrap_final_args_inner(arg)
        arg_info.final_args_fn -> Ast.unwrap_maybe_fn(arg)
        true -> Ast.unwrap_maybe_fn(arg)
      end
      |> Ast.with_state(state)
    end)
  end

  defp maybe_warn(args, fun_info, meta, state) do
    args
    |> Enum.zip(fun_info.args)
    |> Enum.flat_map(fn {arg, arg_info} ->
      cond do
        arg_info.fn &&
          Ast.is_function(arg, arg_info.fn.arity) &&
          not Ast.ok?(arg) &&
            arg_info.fn.warn_not_ok ->
          [arg_info.fn.warn_not_ok]

        arg_info.final_args_fn &&
          Ast.is_function(arg, arg_info.final_args_fn.arity) &&
          not Ast.final_args_ok?(arg) &&
            arg_info.final_args_fn.warn_not_ok ->
          [arg_info.final_args_fn.warn_not_ok]

        true ->
          []
      end
    end)
    |> Enum.each(&Compiler.warn(meta, state, &1))
  end

  defp maybe_warn_static(fun_info, meta, state) do
    if warning = fun_info.warn_always do
      Compiler.warn(meta, state, warning)
    end
  end
end
