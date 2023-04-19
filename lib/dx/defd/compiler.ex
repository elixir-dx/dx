defmodule Dx.Defd.Compiler do
  alias Dx.Defd.Ast
  alias Dx.Defd.Util

  @doc false
  def __compile__(%Macro.Env{module: module, file: file, line: line}, exports, eval_var) do
    defds = compile_prepare_arities(exports)

    state = %{
      module: module,
      file: file,
      line: line,
      function: nil,
      defds: defds,
      args: %{},
      eval_var: eval_var,
      rewrite_underscore?: false
    }

    quoted = Enum.map(exports, &compile_each_defd(&1, state))

    {:__block__, [], quoted}
  end

  defp compile_prepare_arities(definitions) do
    for {{name, arity}, %{defaults: defaults}} <- definitions,
        arity <- (arity - map_size(defaults))..arity,
        into: MapSet.new(),
        do: {name, arity}
  end

  defp compile_each_defd({{name, arity} = def, def_meta}, state) do
    %{defaults: defaults} = def_meta

    {{kind, _meta, args, ast}, state} = get_and_normalize_defd(def, state)

    defd_name = Util.defd_name(name)

    defd_args =
      Enum.with_index(args, fn arg, i ->
        case defaults do
          %{^i => {meta, default}} -> {:\\, meta, [arg, default]}
          %{} -> arg
        end
      end) ++ [state.eval_var]

    all_args = Macro.generate_arguments(arity, __MODULE__)
    Module.delete_definition(state.module, def)

    entrypoint =
      quote line: state.line do
        Kernel.unquote(kind)(unquote(name)(unquote_splicing(all_args))) do
          IO.warn("""
          Use Dx.load as entrypoint.
          """)

          Dx.Defd.load(unquote(name)(unquote_splicing(all_args)))
        end
      end

    impl =
      quote line: state.line do
        Kernel.unquote(kind)(unquote(defd_name)(unquote_splicing(defd_args))) do
          unquote(ast)
        end
      end

    {strip_definition_context(entrypoint), impl}
  end

  # If the definition has a context, we don't warn when it goes unused,
  # so we remove the context as we want to keep the original semantics.
  defp strip_definition_context({kind, meta, [signature, block]}) do
    {kind, meta, [Macro.update_meta(signature, &Keyword.delete(&1, :context)), block]}
  end

  defp get_and_normalize_defd({name, arity} = def, state) do
    {:v1, kind, meta, clauses} = Module.get_definition(state.module, def)

    state = %{state | function: def, line: meta[:line] || state.line, rewrite_underscore?: true}

    type_str = if kind == :def, do: "defd", else: "defdp"

    case clauses do
      [] ->
        compile_error!(meta, state, "cannot have #{type_str} #{name}/#{arity} without clauses")

      [{meta, args, [], ast}] ->
        # {args, state} = normalize_args(args, meta, state)
        {ast, state} =
          with_args(args, state, fn state ->
            normalize(ast, %{state | rewrite_underscore?: false})
          end)

        {{kind, meta, args, ast}, state}

      [_, _ | _] ->
        compile_error!(
          meta,
          state,
          "cannot compile #{type_str} #{name}/#{arity} with multiple clauses"
        )
    end
  end

  # merge given args into state.args for calling fun,
  # then reset state.args to its original value
  defp with_args(args, state, fun) do
    temp_state = Map.update!(state, :args, &Map.merge(&1, args_map(args)))

    case fun.(temp_state) do
      {ast, updated_state} -> {ast, %{updated_state | args: state.args}}
    end
  end

  defp args_map(args) do
    Enum.reduce(args, %{}, fn
      {arg_name, _meta, nil} = arg, acc when is_atom(arg_name) -> Map.put(acc, arg_name, arg)
    end)
  end

  defguardp is_simple(val)
            when is_integer(val) or is_float(val) or is_atom(val) or is_binary(val) or
                   is_boolean(val) or is_nil(val) or is_struct(val)

  def normalize(ast, state) when is_simple(ast) do
    ast = {:ok, ast}
    {ast, state}
  end

  def normalize({arg_name, _meta, nil} = arg, state) when is_atom(arg_name) do
    if Map.has_key?(state.args, arg_name) do
      {{:ok, arg}, state}
    end
  end

  def normalize({fun_name, meta, args} = fun, state)
      when is_atom(fun_name) and is_list(args) do
    arity = length(args)

    cond do
      {fun_name, arity} in state.defds ->
        defd_name = Util.defd_name(fun_name)

        normalize_call_args(args, state, fn args ->
          {defd_name, meta, args ++ [state.eval_var]}
        end)

      Util.has_function?(state.module, fun_name, arity) ->
        warn(meta, state, """
        #{fun_name}/#{arity} is not defined with defd.
        """)

        normalize_call_args(args, state, fn args ->
          {fun_name, meta, args}
        end)

      true ->
        {fun, state}
    end
  end

  def normalize({{:., meta, [module, fun_name]}, meta2, args} = fun, state)
      when is_atom(module) and is_atom(fun_name) and is_list(args) do
    arity = length(args)

    cond do
      Util.is_defd?(module, fun_name, arity) ->
        defd_name = Util.defd_name(fun_name)

        normalize_call_args(args, state, fn args ->
          {{:., meta, [module, defd_name]}, meta2, args ++ [state.eval_var]}
        end)

      Util.has_function?(module, fun_name, arity) ->
        warn(meta2, state, """
        #{inspect(module)}.#{fun_name}/#{arity} is not defined with defd.
        """)

        normalize_call_args(args, state, fn args ->
          {{:., meta, [module, fun_name]}, meta2, args}
        end)

      Code.ensure_loaded?(module) ->
        compile_error!(
          meta,
          state,
          "undefined function #{fun_name}/#{arity} (expected #{inspect(module)} to define such a function, but none are available)"
        )

        {fun, state}

      true ->
        compile_error!(
          meta,
          state,
          "undefined function #{fun_name}/#{arity} (module #{inspect(module)} does not exist)"
        )

        {fun, state}
    end
  end

  # Access.get/2
  def normalize({{:., _meta, [ast, fun_name]}, _meta2, []}, state)
      when is_atom(fun_name) do
    {ast, state} = normalize(ast, state)

    fun =
      quote do
        Dx.Defd.Util.fetch(unquote(ast), unquote(fun_name), unquote(state.eval_var))
      end

    {fun, state}
  end

  def normalize(ast, state) do
    {ast, state}
  end

  def normalize_call_args(args, state, fun) do
    {args, state} = Enum.map_reduce(args, state, &normalize/2)
    ast = args |> Enum.map(&Ast.unwrap/1) |> fun.()

    Ast.ensure_args_loaded(ast, args, state)
  end

  ## Helpers

  defp compile_error!(meta, state, description) do
    line = meta[:line] || state.line
    raise CompileError, line: line, file: state.file, description: description
  end

  defp warn(meta, state, message) do
    line = meta[:line] || state.line
    {name, arity} = state.function
    entry = {state.module, name, arity, [file: String.to_charlist(state.file), line: line]}
    IO.warn(message, [entry])
  end
end
