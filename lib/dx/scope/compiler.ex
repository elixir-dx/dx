defmodule Dx.Scope.Compiler do
  alias Dx.Defd.Ast
  alias Dx.Defd.Util

  import Ast.Guards

  @rewriters %{
    Enum => Dx.Enum,
    :erlang => Dx.Defd.Kernel,
    Kernel => Dx.Defd.Kernel
  }

  def normalize({:fn, meta, [{:->, meta2, [args, body]}]}, state) do
    {body, state} = normalize(body, state)
    args = Ast.mark_vars_as_generated(args)

    {:ok, {:fn, meta, [{:->, meta2, [args, body]}]}}
    |> with_state(state)
  end

  def normalize(var, state) when is_var(var) do
    {{:ok, var}, state}
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

  def normalize({{:., meta, [:erlang, :==]}, _meta2, [left, right]} = ast, state) do
    {n_left, n_state} = normalize(left, state)
    {n_right, n_state} = normalize(right, n_state)

    case {n_left, n_right} do
      {{:ok, left}, {:ok, right}} ->
        quote line: meta[:line] do
          {:ok, Dx.Scope.eq(unquote(left), unquote(right))}
        end

      _else ->
        {fun, _state} =
          {:fn, meta, [{:->, meta, [state.scope_args ++ [state.eval_var], ast]}]}
          |> Dx.Defd.Compiler.normalize_fn(false, state)

        case {n_left, n_right} do
          {{:error, _}, _} ->
            {:error, fun}

          {_, {:error, _}} ->
            {:error, fun}

          _else ->
            quote line: meta[:line] do
              case {unquote(n_left), unquote(n_right)} do
                {{:ok, left}, {:ok, right}} ->
                  {:ok, Dx.Scope.eq(left, right)}

                # {{_, left}, {_, right}} -> {:error, {:ok, left == right}}
                _else ->
                  # :error
                  {:error, unquote(fun)}
              end
            end
        end

        # {:eq, unquote(normalize(left)), unquote(normalize(right))}
    end
    |> with_state(n_state)
  end

  # local_fun()
  def normalize({fun_name, meta, args}, state)
      when is_atom(fun_name) and is_list(args) do
    arity = length(args)

    cond do
      {fun_name, arity} in state.defds ->
        scope_name = Util.scope_name(fun_name)

        {args, state} = Enum.map_reduce(args, state, &normalize/2)

        {scope_name, meta, args}
        |> with_state(state)

      true ->
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

      # function call on dynamically computed module
      not is_atom(module) ->
        :error
        |> with_state(state)

      rewriter = @rewriters[module] ->
        cond do
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
        quote do
          {:error, fn unquote_splicing(args ++ [state.eval_var]) -> {:ok, unquote(fun)} end}
        end
        |> with_state(state)
    end
  end

  def normalize(_other, state) do
    :error
    |> with_state(state)
  end

  ## Helpers

  @compile {:inline, with_state: 2}
  defp with_state(ast, state), do: {ast, state}
end
