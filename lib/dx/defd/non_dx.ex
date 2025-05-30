defmodule Dx.Defd.NonDx do
  @moduledoc """
  Handles calls to functions not defined with defd.

  This module contains logic for warning about and processing calls to regular
  Elixir functions (functions not defined with `defd`) within defd functions.
  """

  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.Loader
  alias Dx.Defd.Ast.State
  alias Dx.Defd.Compiler
  alias Dx.Defd.Util

  import Ast.Guards

  def init(state) do
    Map.merge(state, %{
      warn_non_dx?: true,
      called_non_dx?: false
    })
  end

  def suppress_warnings(state, fun) do
    State.pass_in(state, [warn_non_dx?: false], fun)
  end

  def normalize({{:., meta, [Dx.Defd, :non_dx]}, _meta2, [ast]}, orig_state) do
    State.pass_in(orig_state, [warn_non_dx?: false, called_non_dx?: false], fn state ->
      {ast, state} = Compiler.normalize(ast, state)

      if orig_state.warn_non_dx? and not state.called_non_dx? do
        Compiler.warn(meta, state, """
        No function was called that is not defined with defd.

        Please remove the call to non_dx/1.
        """)
      end

      {ast, state}
    end)
  end

  # &local_fun/2
  def normalize({:&, meta, [{:/, [], [{fun_name, _meta2, nil}, arity]}]} = ast, state) do
    args = Macro.generate_arguments(arity, __MODULE__)
    line = meta[:line] || state.line

    maybe_warn_non_dx(meta, state, "#{fun_name}/#{arity}", Macro.to_string(ast))

    quote line: line do
      {:ok,
       fn unquote_splicing(args) ->
         {:ok, unquote(fun_name)(unquote_splicing(args))}
       end}
    end
    |> with_state(%{state | called_non_dx?: true})
  end

  # &Mod.fun/3
  def normalize(
        {:&, meta, [{:/, [], [{{:., _meta2, [module, fun_name]}, _meta3, []}, arity]}]} = ast,
        state
      ) do
    args = Macro.generate_arguments(arity, __MODULE__)
    line = meta[:line] || state.line

    maybe_warn_non_dx(
      meta,
      state,
      "#{inspect(module)}.#{fun_name}/#{arity}",
      Macro.to_string(ast)
    )

    quote line: line do
      {:ok,
       fn unquote_splicing(args) ->
         {:ok, unquote(module).unquote(fun_name)(unquote_splicing(args))}
       end}
    end
    |> with_state(%{state | called_non_dx?: true})
  end

  # local_fun()
  def normalize({fun_name, meta, args} = fun, state)
      when is_atom(fun_name) and is_list(args) do
    arity = length(args)

    cond do
      Util.has_function?(state.module, fun_name, arity) ->
        maybe_warn_non_dx(meta, state, "#{fun_name}/#{arity}", "#{fun_name}(...)")

        {ast, state} =
          normalize_external_call_args(args, state, fn args ->
            {fun_name, meta, args}
          end)

        {{:ok, ast}, %{state | called_non_dx?: true}}

      true ->
        {{:ok, fun}, state}
    end
  end

  # Mod.fun()
  def normalize({{:., meta, [module, fun_name]}, meta2, args}, state)
      when is_atom(fun_name) and is_list(args) do
    arity = length(args)

    cond do
      # avoid non_dx warning for `Dx.Scope.all/1`
      {module, fun_name, arity} == {Dx.Scope, :all, 1} ->
        normalize_external_call_args(args, state, fn args ->
          {{:., meta, [module, fun_name]}, meta2, args}
        end)
        |> Ast.ok()

      Util.has_function?(module, fun_name, arity) ->
        maybe_warn_non_dx(
          meta2,
          state,
          "#{inspect(module)}.#{fun_name}/#{arity}",
          "#{inspect(module)}.#{fun_name}/#{arity}(...)"
        )

        {ast, state} =
          normalize_external_call_args(args, state, fn args ->
            {{:., meta, [module, fun_name]}, meta2, args}
          end)

        {{:ok, ast}, %{state | called_non_dx?: true}}

      true ->
        {ast, state} =
          normalize_external_call_args(args, state, fn args ->
            {{:., meta, [module, fun_name]}, meta2, args}
          end)

        {{:ok, ast}, state}
    end
  end

  defp normalize_external_call_args(args, state, fun) do
    {args, new_state} =
      Enum.map_reduce(args, state, fn
        {:fn, meta, [{:->, meta2, [args, body]}]}, state ->
          {body, new_state} = normalize_external_fn(body, state)

          {:ok, {:fn, meta, [{:->, meta2, [args, body]}]}}
          |> with_state(new_state)

        {:&, _meta, [{:/, [], [{{:., _meta2, [_mod, _fun_name]}, _meta3, []}, _arity]}]} = fun,
        state ->
          {{:ok, fun}, state}

        {:&, _meta, [{:/, [], [{_fun_name, _meta2, nil}, _arity]}]} = fun, state ->
          {{:ok, fun}, state}

        arg, state ->
          Compiler.normalize(arg, state)
      end)

    {args, new_state} = args |> Enum.map(&Ast.unwrap/1) |> finalize_args(new_state)

    Compiler.do_normalize_call_args(args, new_state, fun)
  end

  # extracts only loaders based on variables bound outside of the external anonymous function
  defp normalize_external_fn(ast, state) do
    Macro.prewalk(ast, state, fn
      {{:., _meta, [_module, fun_name]}, meta2, args} = fun, state
      when is_atom(fun_name) and is_list(args) ->
        # Access.get/2
        if meta2[:no_parens] do
          case Compiler.maybe_capture_loader(fun, state) do
            {:ok, _loader_ast, state} ->
              subject = root_var_from_access_chain(fun)
              data_req = data_req_from_access_chain(fun, %{})

              {{:ok, var}, state} =
                quote do
                  Dx.Defd.Runtime.fetch(
                    unquote(subject),
                    unquote(Macro.escape(data_req)),
                    unquote(state.eval_var)
                  )
                end
                |> Loader.add(state)

              replace_root_var(fun, var)
              |> with_state(state)

            :error ->
              {fun, state}
          end
        else
          {fun, state}
        end

      ast, state ->
        {ast, state}
    end)
  end

  defp root_var_from_access_chain({{:., _meta, [ast, _fun_name]}, _meta2, []}) do
    root_var_from_access_chain(ast)
  end

  defp root_var_from_access_chain(var) when is_var(var) do
    var
  end

  defp data_req_from_access_chain({{:., _meta, [ast, fun_name]}, _meta2, []}, acc) do
    acc = %{fun_name => acc}
    data_req_from_access_chain(ast, acc)
  end

  defp data_req_from_access_chain(var, acc) when is_var(var) do
    acc
  end

  defp replace_root_var({{:., meta, [ast, fun_name]}, meta2, []}, new_var) do
    {{:., meta, [replace_root_var(ast, new_var), fun_name]}, meta2, []}
  end

  defp replace_root_var(var, new_var) when is_var(var) do
    new_var
  end

  defp finalize_args(args, state) do
    Enum.map_reduce(args, state, fn arg, state ->
      vars = Ast.collect_vars(arg)

      if MapSet.subset?(vars, state.finalized_vars) do
        {:ok, arg}
        |> with_state(state)
      else
        quote do
          Dx.Defd.Runtime.finalize(unquote(arg), unquote(state.eval_var))
        end
        |> Loader.add(state)
      end
    end)
  end

  ## Helpers

  @compile {:inline, with_state: 2}
  defp with_state(ast, state), do: {ast, state}

  # Helper to emit a warning for non-defd functions
  defp maybe_warn_non_dx(meta, state, mod_str, wrap_str) do
    if state.warn_non_dx? do
      Compiler.warn(meta, state, """
      #{mod_str} is not defined with defd.

      Either define it using defd (preferred) or wrap the call in the non_dx/1 function:

          non_dx(#{wrap_str})
      """)
    end
  end
end
