defmodule Dx.Scope.Compiler do
  @moduledoc false

  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.State
  alias Dx.Defd.Util

  import Ast.Guards

  @rewriters %{
    Enum => Dx.Enum,
    :erlang => Dx.Defd.Kernel,
    Kernel => Dx.Defd.Kernel,
    String.Chars => Dx.Defd.String.Chars
  }

  def generate_fallback(ast, meta, state) do
    {fun, _state} =
      Ast.with_args_no_loaders!(state.scope_args, state, fn state ->
        args = state.scope_args ++ [state.eval_var]

        {ast, new_state} =
          Ast.with_root_args(args, state, fn state ->
            Dx.Defd.Compiler.normalize(ast, state)
          end)

        {:fn, meta, [{:->, meta, [args, ast]}]}
        |> with_state(new_state)
      end)

    fun
  end

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

  def normalize({:case, _meta, _args} = ast, state) do
    Dx.Scope.Case.normalize(ast, state)
  end

  # &local_fun/2
  def normalize({:&, meta, [{:/, [], [{fun_name, [], nil}, arity]}]} = ast, state) do
    if {fun_name, arity} in state.defds do
      scope_name = Util.scope_name(fun_name)
      args = Macro.generate_arguments(arity, __MODULE__)

      {:fn, meta, [{:->, meta, [args, {scope_name, meta, args}]}]}
    else
      fallback = generate_fallback(ast, meta, state)

      {:error, fallback}
    end
    |> with_state(state)
  end

  # &Mod.fun/3
  def normalize(
        {:&, meta, [{:/, [], [{{:., [], [module, fun_name]}, [], []}, arity]}]} = ast,
        state
      ) do
    cond do
      rewriter = @rewriters[module] ->
        rewriter.rewrite_scope(ast, state)

      Util.is_defd?(module, fun_name, arity) ->
        scope_name = Util.scope_name(fun_name)
        args = Macro.generate_arguments(arity, __MODULE__)

        {:fn, meta, [{:->, meta, [args, {{:., meta, [module, scope_name]}, meta, args}]}]}
        |> with_state(state)

      true ->
        {fun, _state} =
          Ast.with_args_no_loaders!(state.scope_args, state, fn state ->
            args = state.scope_args

            {ast, new_state} =
              Ast.with_root_args(args, state, fn state ->
                Dx.Defd.Compiler.normalize(ast, state)
              end)

            {:fn, meta, [{:->, meta, [args, ast]}]}
            |> with_state(new_state)
          end)

        {:error, fun}
        |> with_state(state)
    end
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
        fallback = generate_fallback(call, meta, state)

        {:error, fallback}
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
        fallback = generate_fallback(fun, meta, state)

        {:error, fallback}
        |> with_state(state)

      rewriter = @rewriters[module] ->
        Code.ensure_loaded(rewriter)

        scopable_args = Util.scopable_args(rewriter, fun_name, arity)

        cond do
          Util.scope_defined?(rewriter, fun_name, arity) ->
            {args, state} = Enum.map_reduce(args, state, &normalize/2)

            args =
              Dx.Util.Enum.map_indexes(args, scopable_args, fn
                atom when is_atom(atom) -> quote do: Dx.Scope.all(unquote(atom))
                arg -> quote do: Dx.Scope.maybe_atom(unquote(arg))
              end)

            generate_fallback = fn -> generate_fallback(fun, meta, state) end

            apply(rewriter, Util.scope_name(fun_name), args ++ [generate_fallback])
            |> with_state(state)

          Util.is_scopable?(rewriter, fun_name, arity) ->
            {args, state} = Enum.map_reduce(args, state, &normalize/2)

            {{:., meta, [rewriter, fun_name]}, meta2, args}
            |> with_state(state)

          true ->
            fallback = generate_fallback(fun, meta, state)

            {:error, fallback}
            |> with_state(state)
        end

      Util.is_defd?(module, fun_name, arity) ->
        scope_name = Util.scope_name(fun_name)

        {{:., meta, [module, scope_name]}, meta2, args}
        |> with_state(state)

      true ->
        fallback = generate_fallback(fun, meta, state)

        {:error, fallback}
        |> with_state(state)
    end
  end

  def normalize(other, state) do
    meta = Ast.closest_meta(other)
    fallback = generate_fallback(other, meta, state)

    {:error, fallback}
    |> with_state(state)
  end

  ## Helpers

  @compile {:inline, with_state: 2}
  defp with_state(ast, state), do: {ast, state}
end
