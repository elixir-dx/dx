defmodule Dx.Scope.Compiler do
  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.State
  alias Dx.Defd.Util

  import Ast.Guards

  @rewriters %{
    Enum => Dx.Enum,
    :erlang => Dx.Defd.Kernel,
    Kernel => Dx.Defd.Kernel
  }

  def normalize({:fn, meta, [{:->, meta2, [args, body]}]}, state) do
    {body, state} =
      State.pass_in(state, [scope_args: args], fn state ->
        Ast.with_args_no_loaders!(args, state, fn state ->
          normalize(body, state)
        end)
      end)

    args = Ast.mark_vars_as_generated(args)

    {:fn, meta, [{:->, meta2, [args, body]}]}
    |> with_state(state)
  end

  def normalize(var, state) when is_var(var) do
    {var, state}
  end

  def normalize(value, state) when is_simple(value) do
    value
    |> with_state(state)
  end

  # local_fun()
  def normalize({fun_name, meta, args} = call, state)
      when is_atom(fun_name) and is_list(args) do
    arity = length(args)

    cond do
      {fun_name, arity} in state.defds ->
        scope_name = Util.scope_name(fun_name)

        {args, state} = Enum.map_reduce(args, state, &normalize/2)

        {scope_name, meta, args}
        |> with_state(state)

      true ->
        {fun, _state} =
          Ast.with_args_no_loaders!(state.scope_args, state, fn state ->
            {:fn, meta, [{:->, meta, [state.scope_args ++ [state.eval_var], call]}]}
            |> Dx.Defd.Compiler.normalize_fn(false, state)
          end)

        {:error, fun}
        |> with_state(state)
    end
  end

  # Mod.fun()
  def normalize({{:., meta, [module, fun_name]}, meta2, args} = fun, state)
      when is_atom(fun_name) and is_list(args) do
    arity = length(args)

    cond do
      # Access.get/2
      meta2[:no_parens] ->
        {module, state} = normalize(module, state)

        case module do
          {:ok, module} ->
            quote line: meta[:line] do
              {:ok, {:field_or_assoc, unquote(module), unquote(fun_name)}}
            end

          _other ->
            quote line: meta[:line] do
              {:field_or_assoc, unquote(module), unquote(fun_name)}
            end
        end
        |> with_state(state)

      # function call on dynamically computed module
      not is_atom(module) ->
        :error
        |> with_state(state)

      rewriter = @rewriters[module] ->
        Code.ensure_loaded(rewriter)

        cond do
          function_exported?(rewriter, Util.scope_name(fun_name), arity + 1) ->
            {args, state} = Enum.map_reduce(args, state, &normalize/2)

            generate_fallback = fn ->
              {fun, _state} =
                Ast.with_args_no_loaders!(state.scope_args, state, fn state ->
                  {:fn, meta, [{:->, meta, [state.scope_args ++ [state.eval_var], fun]}]}
                  |> Dx.Defd.Compiler.normalize_fn(false, state)
                end)

              fun
            end

            apply(rewriter, Util.scope_name(fun_name), args ++ [generate_fallback])
            |> with_state(state)

          Util.is_scopable?(rewriter, fun_name, arity) ->
            {args, state} = Enum.map_reduce(args, state, &normalize/2)

            {{:., meta, [rewriter, fun_name]}, meta2, args}
            |> with_state(state)

          function_exported?(rewriter, fun_name, arity) ->
            :error
            |> with_state(state)

          true ->
            :error
            |> with_state(state)
        end

      Util.is_defd?(module, fun_name, arity) ->
        scope_name = Util.scope_name(fun_name)

        {{:., meta, [module, scope_name]}, meta2, args}
        |> with_state(state)

      true ->
        {fun, _state} =
          Ast.with_args_no_loaders!(state.scope_args, state, fn state ->
            {:fn, meta, [{:->, meta, [state.scope_args ++ [state.eval_var], fun]}]}
            |> Dx.Defd.Compiler.normalize_fn(false, state)
          end)

        {:error, fun}
        |> with_state(state)
    end
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
