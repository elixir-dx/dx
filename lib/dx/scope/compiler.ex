defmodule Dx.Scope.Compiler do
  alias Dx.Defd.Util

  import Dx.Defd.Ast.Guards

  @eval_var Macro.var(:eval, Dx.Defd.Compiler)
  @rewriters %{
    Enum => Dx.Enum,
    :erlang => Dx.Defd.Kernel,
    Kernel => Dx.Defd.Kernel
  }

  # def normalize(ast) do
  #   state = %{
  #     defds: %{}
  #   }

  #   {ast, _state} = normalize(ast, state)
  #   ast
  # end

  def normalize({:fn, meta, [{:->, meta2, [args, body]}]}, state) do
    {body, state} = normalize(body, state)

    {:ok, {:fn, meta, [{:->, meta2, [args, body]}]}}
    |> with_state(state)
  end

  def normalize(var, state) when is_var(var) do
    {var, state}
  end

  def normalize(value, state) when is_simple(value) do
    {:ok, {:value, value}}
    |> with_state(state)
  end

  # def normalize({{:., meta, [ast, fun_name]}, meta2, []}) do
  #   cond do
  #     meta2[:no_parens] ->
  #       quote line: meta[:line] do
  #         {:field, unquote(normalize(ast)), unquote(fun_name)}
  #       end
  #   end
  # end

  def normalize({{:., meta, [:erlang, :==]}, _meta2, [left, right]}, state) do
    {left, state} = normalize(left, state)
    {right, state} = normalize(right, state)

    quote line: meta[:line] do
      case {unquote(left), unquote(right)} do
        {{:ok, left}, {:ok, right}} ->
          {:ok, Dx.Scope.eq(left, right)}

        # {{_, left}, {_, right}} -> {:error, {:ok, left == right}}
        _else ->
          :error
      end

      # {:eq, unquote(normalize(left)), unquote(normalize(right))}
    end
    |> with_state(state)
  end

  # local_fun()
  def normalize({fun_name, meta, args} = fun, state)
      when is_atom(fun_name) and is_list(args) do
    arity = length(args)

    cond do
      {fun_name, arity} in state.defds ->
        scope_name = Util.scope_name(fun_name)

        {args, state} = Enum.map_reduce(args, state, &normalize/2)

        {scope_name, meta, args}
        |> with_state(state)

      true ->
        # {:error, {:ok, fun}}
        :error
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

        quote line: meta[:line] do
          {:ok, Dx.Scope.field_or_assoc(unquote(module), unquote(fun_name))}
        end
        |> with_state(state)

      # # function call on dynamically computed module
      # not is_atom(module) ->

      rewriter = @rewriters[module] ->
        cond do
          Util.is_scopable?(rewriter, fun_name, arity) ->
            {args, state} = Enum.map_reduce(args, state, &normalize/2)

            {{:., meta, [rewriter, fun_name]}, meta2, args}
            |> with_state(state)

          function_exported?(rewriter, fun_name, arity) ->
            # {:error, {{:., meta, [rewriter, fun_name]}, meta2, args}}
            :error
            |> with_state(state)

          true ->
            # {:error, {:ok, fun}}
            :error
            |> with_state(state)
        end

      Util.is_defd?(module, fun_name, arity) ->
        scope_name = Util.scope_name(fun_name)

        {{:., meta, [module, scope_name]}, meta2, args}
        |> with_state(state)

      true ->
        # {:error, {:ok, fun}}
        :error
        |> with_state(state)
    end
  end

  defp if_all_ok(args, then_ast, else_ast) do
    Enum.reduce(args, [], fn
      {:ok, arg}, acc -> acc
      ast, [] -> ast
      ast, acc -> quote do: unquote(acc) and unquote(ast)
    end)
    |> case do
      [] -> then_ast
      cond_ast -> quote do: if(unquote(cond_ast), do: unquote(then_ast), else: unquote(else_ast))
    end
  end

  defp with_state(ast, state), do: {ast, state}
end
