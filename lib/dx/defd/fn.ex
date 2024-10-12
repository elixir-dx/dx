defmodule Dx.Defd.Fn do
  @moduledoc false

  defstruct [:ok?, :final_args_ok?, :fun, :ok_fun, :final_args_fun, :final_args_ok_fun, :scope]

  def maybe_unwrap(%__MODULE__{fun: fun}), do: fun
  def maybe_unwrap(other), do: other

  def maybe_unwrap_ok(%__MODULE__{ok_fun: fun}), do: fun
  def maybe_unwrap_ok(other), do: other

  def maybe_unwrap_final_args_ok(%__MODULE__{final_args_ok_fun: fun}), do: fun
  def maybe_unwrap_final_args_ok(other), do: other

  def to_defd_fun(%__MODULE__{fun: fun}), do: fun
  def to_defd_fun(fun) when is_function(fun), do: wrap_defd_fun(fun)
  def to_defd_fun(other), do: other

  wrap_defd_args = Macro.generate_arguments(12, __MODULE__)

  for arity <- 0..12, args = Enum.take(wrap_defd_args, arity) do
    defp wrap_defd_fun(fun) when is_function(fun, unquote(arity)) do
      fn unquote_splicing(args) ->
        {:ok, fun.(unquote_splicing(args))}
      end
    end
  end

  ## Compiler

  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.State
  alias Dx.Defd.Compiler

  def normalize({:fn, meta, clauses}, state) do
    {clauses, state} = Enum.map_reduce(clauses, state, &normalize_clause/2)

    line = meta[:line] || state.line

    ok? = Enum.all?(clauses, & &1[:ok?])
    final_args_ok? = Enum.all?(clauses, & &1[:final_args_ok?])

    {:ok,
     {:%, [line: line],
      [
        {:__aliases__, [line: line, alias: false], [:Dx, :Defd, :Fn]},
        {:%{}, [line: line],
         [
           ok?: ok?,
           final_args_ok?: final_args_ok?,
           fun: {:fn, meta, Enum.map(clauses, & &1[:fun])},
           ok_fun: if(ok?, do: {:fn, meta, Enum.map(clauses, & &1[:ok_fun])}),
           final_args_fun: {:fn, meta, Enum.map(clauses, & &1[:final_args_fun])},
           final_args_ok_fun:
             if(final_args_ok?, do: {:fn, meta, Enum.map(clauses, & &1[:final_args_ok_fun])}),
           scope: {:fn, meta, Enum.map(clauses, & &1[:scope])}
         ]}
      ]}}
    |> with_state(state)
  end

  def normalize_clause({:->, meta2, [args, body]}, state) do
    external_scope_args = Macro.generate_arguments(length(args), Dx.Scope.Compiler)
    internal_scope_args = Ast.mark_vars_as_generated(args)
    scope_args_map = Enum.zip(external_scope_args, internal_scope_args)

    scope_args =
      Enum.map(scope_args_map, fn {external_arg, internal_arg} ->
        quote do: unquote(external_arg) = unquote(internal_arg)
      end)

    {scope_body, scope_state} =
      State.pass_in(
        state,
        [warn_non_dx?: false, scope_args: Enum.zip(external_scope_args, internal_scope_args)],
        fn state ->
          Ast.with_args_no_loaders!(args, state, fn state ->
            Dx.Scope.Compiler.normalize(body, state)
          end)
        end
      )

    {final_args_body, final_args_state} =
      State.pass_in(
        state,
        [warn_non_dx?: false, finalized_vars: &Ast.collect_vars(args, &1)],
        fn state ->
          Ast.with_root_args(args, state, fn state ->
            Compiler.normalize(body, state)
          end)
        end
      )

    {final_args_ok?, final_args_ok_body} =
      case final_args_body do
        {:ok, final_args_ok_body} -> {true, final_args_ok_body}
        _ -> {false, nil}
      end

    {defd_body, new_state} =
      Ast.with_root_args(args, state, fn state ->
        Compiler.normalize(body, state)
      end)

    {ok?, ok_body} =
      case defd_body do
        {:ok, ok_body} -> {true, ok_body}
        _ -> {false, nil}
      end

    var_index = Enum.max([scope_state.var_index, final_args_state.var_index, new_state.var_index])
    new_state = %{new_state | var_index: var_index}

    [
      ok?: ok?,
      final_args_ok?: final_args_ok?,
      fun: {:->, meta2, [args, defd_body]},
      ok_fun: if(ok?, do: {:->, meta2, [args, ok_body]}),
      final_args_fun: {:->, meta2, [args, final_args_body]},
      final_args_ok_fun: if(final_args_ok?, do: {:->, meta2, [args, final_args_ok_body]}),
      scope: {:->, meta2, [scope_args, scope_body]}
    ]
    |> with_state(new_state)
  end

  ## Helpers

  @compile {:inline, with_state: 2}
  defp with_state(ast, state), do: {ast, state}
end
