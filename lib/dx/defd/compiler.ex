defmodule Dx.Defd.Compiler do
  @moduledoc false

  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.Loader
  alias Dx.Defd.Ast.State
  alias Dx.Defd.Util

  import Ast.Guards

  @rewriters %{
    DateTime => Dx.DateTime,
    Enum => Dx.Enum,
    :erlang => Dx.Defd.Kernel,
    Kernel => Dx.Defd.Kernel,
    String.Chars => Dx.Defd.String.Chars
  }

  # @queryables Protocol.extract_impls(Ecto.Queryable)

  @doc false
  def __compile__(%Macro.Env{module: module, file: file, line: line}, exports, eval_var) do
    defds = compile_prepare_arities(exports)
    all_arities = all_arities(exports)

    state = %{
      module: module,
      file: file,
      line: line,
      function: nil,
      defds: defds,
      all_arities: all_arities,
      used_defds: MapSet.new(),
      args: MapSet.new(),
      var_index: 1,
      scope_args: [],
      eval_var: eval_var,
      warn_non_dx?: true,
      called_non_dx?: false,
      loaders: [],
      finalized_vars: MapSet.new(),
      rewrite_underscore?: false
    }

    {quoted, state} =
      Enum.flat_map_reduce(exports, state, fn def, state ->
        {definitions, new_state} = compile_each_defd(def, state)

        state = %{state | used_defds: new_state.used_defds}

        {definitions, state}
      end)

    generated_functions =
      Enum.flat_map(defds, fn {name, arity} ->
        [
          {Util.defd_name(name), arity + 1},
          {Util.final_args_name(name), arity + 1},
          {Util.scope_name(name), arity}
        ]
      end)

    suppress_unused_warnings_ast =
      case MapSet.to_list(state.used_defds) ++ generated_functions do
        [] ->
          []

        defs ->
          ast = Enum.map(defs, &Ast.local_fun_ref/1)

          [
            quote do
              def unquote(:"__dx:suppress_unused_warnings__")() do
                unquote(ast)
              end
            end
          ]
      end

    Ast.block(suppress_unused_warnings_ast ++ quoted)
  end

  defp compile_prepare_arities(definitions) do
    for {{name, arity}, %{defaults: defaults}} <- definitions,
        arity <- (arity - map_size(defaults))..arity,
        into: MapSet.new(),
        do: {name, arity}
  end

  defp all_arities(definitions) do
    Map.new(definitions, fn {{_name, arity} = def, %{defaults: defaults}} ->
      {def, (arity - map_size(defaults))..arity}
    end)
  end

  defp compile_each_defd({{name, arity} = def, def_meta}, state) do
    %{defaults: defaults, opts: opts} = def_meta
    debug_flags = List.wrap(opts[:debug])

    all_args = Macro.generate_arguments(arity, __MODULE__)
    state = Map.put(state, :all_args, all_args)

    {{kind, meta, args, ast}, {scope_args, scope_ast}, {final_args_args, final_args_ast}, state} =
      get_and_normalize_defd_and_scope(def, state)

    defd_name = Util.defd_name(name)
    final_args_name = Util.final_args_name(name)
    scope_name = Util.scope_name(name)

    scope_ast =
      case scope_ast do
        {:error, _} ->
          {:error,
           {:&, meta, [{:/, [], [{{:., meta, [state.module, defd_name]}, meta, []}, arity + 1]}]}}

        other ->
          other
      end

    all_args_with_defaults =
      Enum.with_index(all_args, fn arg, i ->
        case defaults do
          %{^i => {meta, default}} -> {:\\, meta, [arg, default]}
          %{} -> arg
        end
      end)

    scope_args =
      Enum.with_index(scope_args, fn arg, i ->
        case defaults do
          %{^i => {meta, default}} -> {:\\, meta, [arg, default]}
          %{} -> arg
        end
      end)

    defd_args =
      Enum.with_index(args, fn arg, i ->
        case defaults do
          %{^i => {meta, default}} -> {:\\, meta, [arg, default]}
          %{} -> arg
        end
      end)

    final_args_args =
      Enum.with_index(final_args_args, fn arg, i ->
        case defaults do
          %{^i => {meta, default}} -> {:\\, meta, [arg, default]}
          %{} -> arg
        end
      end)

    defd_args = append_arg(defd_args, state.eval_var)
    final_args_args = append_arg(final_args_args, state.eval_var)

    entrypoints =
      case Keyword.get(opts, :def, :warn) do
        :warn ->
          for arity <- state.all_arities[def],
              do: Module.delete_definition(state.module, {name, arity})

          quote line: state.line do
            unquote(kind)(unquote(name)(unquote_splicing(all_args_with_defaults))) do
              IO.warn("""
              Use Dx.Defd.load as entrypoint.
              """)

              Dx.Defd.load!(unquote(name)(unquote_splicing(all_args)))
            end
          end
          |> strip_definition_context()
          |> List.wrap()

        :no_warn ->
          for arity <- state.all_arities[def],
              do: Module.delete_definition(state.module, {name, arity})

          quote line: state.line do
            unquote(kind)(unquote(name)(unquote_splicing(all_args_with_defaults))) do
              Dx.Defd.load!(unquote(name)(unquote_splicing(all_args)))
            end
          end
          |> strip_definition_context()
          |> List.wrap()

        :original ->
          []

        invalid ->
          compile_error!(meta, state, "Invalid option @dx def: #{inspect(invalid)}")
      end

    defd = define_function(kind, defd_name, state.line, defd_args, ast)

    if Enum.any?([:compiled, :all], &(&1 in debug_flags)), do: Ast.p(defd)

    final_args =
      define_function(kind, final_args_name, state.line, final_args_args, final_args_ast)

    if Enum.any?([:compiled_final_args, :all], &(&1 in debug_flags)), do: Ast.p(final_args)

    scope =
      quote line: state.line do
        unquote(kind)(unquote(scope_name)(unquote_splicing(scope_args))) do
          unquote(scope_ast)
        end
      end

    definitions = entrypoints ++ [defd, final_args, scope]

    {definitions, state}
  end

  defp append_arg({:when, meta, [args | guards]}, arg),
    do: {:when, meta, [args ++ [arg] | guards]}

  defp append_arg(args, arg), do: args ++ [arg]

  defp define_function(kind, name, line, {:when, _, [args | guards]}, ast) do
    quote line: line do
      unquote(kind)(
        unquote(name)(unquote_splicing(args))
        when unquote_splicing(guards)
      ) do
        unquote(ast)
      end
    end
  end

  defp define_function(kind, name, line, args, ast) do
    quote line: line do
      unquote(kind)(unquote(name)(unquote_splicing(args))) do
        unquote(ast)
      end
    end
  end

  # If the definition has a context, we don't warn when it goes unused,
  # so we remove the context as we want to keep the original semantics.
  defp strip_definition_context({kind, meta, [signature, block]}) do
    {kind, meta, [Macro.update_meta(signature, &Keyword.delete(&1, :context)), block]}
  end

  defp get_and_normalize_defd_and_scope({name, arity} = def, state) do
    {:v1, kind, meta, clauses} = Module.get_definition(state.module, def)

    state = %{state | function: def, line: meta[:line] || state.line, rewrite_underscore?: true}

    type_str = if kind == :def, do: "defd", else: "defdp"

    {{scope_args, scope_ast}, scope_state} =
      Dx.Scope.Compiler.normalize_function({:v1, kind, meta, clauses}, state)

    case clauses do
      [] ->
        compile_error!(meta, state, "cannot have #{type_str} #{name}/#{arity} without clauses")

      [{meta, _args, _, _} | _] = clauses ->
        case_clauses =
          Enum.map(clauses, fn
            {meta, args, [], ast} ->
              {:->, meta, [[Ast.wrap_args(args)], ast]}

            {meta, args, guards, ast} ->
              {:->, meta, [[{:when, [], [Ast.wrap_args(args) | guards]}], ast]}
          end)

        line = meta[:line] || state.line
        case_subject = Ast.wrap_args(state.all_args)
        case_ast = {:case, [line: line], [case_subject, [do: case_clauses]]}

        {final_args_ast, final_args_state} =
          State.pass_in(
            state,
            [warn_non_dx?: false, finalized_vars: &Ast.collect_vars(state.all_args, &1)],
            fn state ->
              Ast.with_root_args(state.all_args, state, fn state ->
                Dx.Defd.Case.normalize(case_ast, state)
              end)
            end
          )

        {{final_args_args, final_args_ast}, final_args_state} =
          maybe_unwrap_case(final_args_ast, final_args_state)

        {ast, state} =
          Ast.with_root_args(state.all_args, state, fn state ->
            Dx.Defd.Case.normalize(case_ast, state)
          end)

        {{args, ast}, state} = maybe_unwrap_case(ast, state)

        var_index = Enum.max([scope_state.var_index, final_args_state.var_index, state.var_index])
        new_state = %{state | var_index: var_index}

        {{kind, meta, args, ast}, {scope_args, scope_ast}, {final_args_args, final_args_ast},
         new_state}
    end
  end

  defp maybe_unwrap_case(
         {:case, _meta,
          [_case_subject, [do: [{:->, _clause_meta, [[clause_args], clause_ast]}]]]},
         state
       ) do
    case state.all_args do
      [_] ->
        {{[clause_args], clause_ast}, state}

      _else ->
        {{clause_args, clause_ast}, state}
    end
  end

  defp maybe_unwrap_case(ast, state) do
    {{state.all_args, ast}, state}
  end

  def normalize(ast, state) when is_simple(ast) do
    {:ok, ast}
    |> with_state(state)
  end

  # []
  def normalize([], state) do
    {:ok, []}
    |> with_state(state)
  end

  # [...]
  # [... | ...]
  def normalize(ast, state) when is_list(ast) do
    {reverse_ast, prepend_meta} =
      case Enum.reverse(ast) do
        [{:|, meta, [prev_last, last]} | elems] -> {[last, prev_last | elems], meta}
        elems -> {elems, nil}
      end

    {ast, state} =
      Enum.reduce(reverse_ast, {[], state}, fn elem, {elems, state} ->
        {elem, state} = normalize(elem, state)
        {[elem | elems], state}
      end)

    case {Dx.Defd.Result.collect_ok_reverse(ast, []), prepend_meta} do
      {{:ok, reverse_ast}, nil} ->
        # unwrapped at compile-time
        {:ok, Enum.reverse(reverse_ast)}

      {{:ok, [last, prev_last | reverse_elems]}, prepend_meta} ->
        # unwrapped at compile-time & prepend
        {:ok, Enum.reverse(reverse_elems, [{:|, prepend_meta, [prev_last, last]}])}

      {:error, nil} ->
        # unwrap at runtime
        line =
          case ast do
            [{_, meta, _} | _] -> meta[:line] || state.line
            _other -> state.line
          end

        quote line: line do
          Dx.Defd.Result.collect(unquote(ast))
        end

      {:error, _prepend_meta} ->
        # unwrap at runtime & prepend
        line =
          case ast do
            [{_, meta, _} | _] -> meta[:line] || state.line
            _other -> state.line
          end

        quote line: line do
          case Dx.Defd.Result.collect(unquote(ast)) do
            {:ok, [last, prev_last | reverse_elems]} ->
              {:ok, Enum.reverse(reverse_elems, [prev_last, last])}

            other ->
              other
          end
        end
    end
    |> with_state(state)
  end

  # {_, _}
  def normalize({elem_0, elem_1}, state) do
    {[elem_0, elem_1], state} = Enum.map_reduce([elem_0, elem_1], state, &normalize_load_unwrap/2)

    {:ok, {elem_0, elem_1}}
    |> with_state(state)
  end

  # {...}
  def normalize({:{}, meta, elems}, state) do
    {elems, state} = Enum.map_reduce(elems, state, &normalize_load_unwrap/2)

    {:ok, {:{}, meta, elems}}
    |> with_state(state)
  end

  def normalize({:<<>>, meta, parts}, state) when is_list(parts) do
    {parts, state} =
      Enum.map_reduce(parts, state, fn
        {:"::", meta, [ast, {:binary, binary_meta, context}]}, state ->
          {ast, state} = normalize_load_unwrap(ast, state)

          {:"::", meta, [ast, {:binary, binary_meta, context}]}
          |> with_state(state)

        part, state ->
          {part, state}
      end)

    {:ok, {:<<>>, meta, parts}}
    |> with_state(state)
  end

  # %{...}
  def normalize({:%{}, meta, pairs}, state) do
    {flat_ast, state} = pairs |> Ast.flatten_kv_list() |> Enum.map_reduce(state, &normalize/2)

    case Dx.Defd.Result.collect_ok(flat_ast) do
      {:ok, flat_ast} ->
        # unwrapped at compile-time
        {:ok, {:%{}, meta, Ast.unflatten_kv_list(flat_ast)}}

      :error ->
        # unwrap at runtime
        line =
          case flat_ast do
            [{_, meta, _} | _] -> meta[:line] || state.line
            _other -> state.line
          end

        quote line: line do
          Dx.Defd.Result.collect_map_pairs(unquote(flat_ast))
        end
    end
    |> with_state(state)
  end

  def normalize(var, state) when is_var(var) do
    {:ok, var}
    |> with_state(state)
  end

  def normalize({{:., meta, [Dx.Defd, :non_dx]}, _meta2, [ast]}, orig_state) do
    State.pass_in(orig_state, [warn_non_dx?: false, called_non_dx?: false], fn state ->
      {ast, state} = normalize(ast, state)

      if orig_state.warn_non_dx? and not state.called_non_dx? do
        warn(meta, state, """
        No function was called that is not defined with defd.

        Please remove the call to non_dx/1.
        """)
      end

      {ast, state}
    end)
  end

  def normalize({:fn, _meta, clauses} = fun, state) when is_list(clauses) do
    Dx.Defd.Fn.normalize(fun, state)
  end

  # fun.()
  def normalize({{:., meta, [fun]}, meta2, args}, state) do
    {fun, state} = normalize(fun, state)
    fun = Ast.to_defd_fun(fun)

    normalize_call_args(args, state, fn args ->
      {{:., meta, [fun]}, meta2, args}
    end)
    |> Loader.add()
  end

  def normalize({:case, _meta, _args} = ast, state) do
    Dx.Defd.Case.normalize(ast, state)
  end

  def normalize({:cond, _meta, _args} = ast, state) do
    Dx.Defd.Cond.normalize(ast, state)
  end

  def normalize({:__block__, _meta, _lines} = ast, state) do
    Dx.Defd.Block.normalize(ast, state)
  end

  def normalize({:=, meta, [pattern, right]}, state) do
    {right, state} = normalize(right, state)
    right = Ast.unwrap(right)

    state = Map.update!(state, :args, &Ast.collect_vars(pattern, &1))
    data_req = Ast.Pattern.quoted_data_req(pattern, :preloads)

    if data_req == %{} do
      {:ok, {:=, meta, [pattern, right]}}
      |> with_state(state)
    else
      {{:ok, var}, state} =
        quote do
          Dx.Defd.Runtime.fetch(
            unquote(right),
            unquote(Macro.escape(data_req)),
            unquote(state.eval_var)
          )
        end
        |> Loader.add(state)

      {:ok, {:=, meta, [pattern, var]}}
      |> with_state(state)
    end
  end

  # &local_fun/2
  def normalize({:&, meta, [{:/, [], [{fun_name, meta2, nil}, arity]}]}, state) do
    args = Macro.generate_arguments(arity, __MODULE__)
    line = meta[:line] || state.line

    if {fun_name, arity} in state.defds do
      defd_name = Util.defd_name(fun_name)
      final_args_name = Util.final_args_name(fun_name)
      scope_name = Util.scope_name(fun_name)

      state = Map.update!(state, :used_defds, &MapSet.put(&1, {fun_name, arity}))

      {:ok,
       {:%, [line: line],
        [
          {:__aliases__, [line: line, alias: false], [:Dx, :Defd, :Fn]},
          {:%{}, [line: line],
           [
             ok?: false,
             final_args_ok?: false,
             fun: {:fn, meta, [{:->, meta, [args, {defd_name, meta, args ++ [state.eval_var]}]}]},
             final_args_fun:
               {:fn, meta,
                [{:->, meta, [args, {final_args_name, meta, args ++ [state.eval_var]}]}]},
             scope: {:&, meta, [{:/, [], [{scope_name, meta2, nil}, arity]}]}
           ]}
        ]}}
      |> with_state(state)
    else
      if state.warn_non_dx? do
        warn(meta, state, """
        #{fun_name}/#{arity} is not defined with defd.

        Either define it using defd (preferred) or wrap the call in the non_dx/1 function:

            non_dx(...(&#{fun_name}/#{arity}))
        """)
      end

      quote line: line do
        {:ok,
         fn unquote_splicing(args) ->
           {:ok, unquote(fun_name)(unquote_splicing(args))}
         end}
      end
      |> with_state(%{state | called_non_dx?: true})
    end
  end

  # &Mod.fun/3
  def normalize(
        {:&, meta, [{:/, [], [{{:., meta2, [module, fun_name]}, meta3, []}, arity]}]} = fun,
        state
      ) do
    args = Macro.generate_arguments(arity, __MODULE__)
    line = meta[:line] || state.line

    cond do
      rewriter = @rewriters[module] ->
        rewriter.rewrite(fun, state)

      Util.is_defd?(module, fun_name, arity) ->
        defd_name = Util.defd_name(fun_name)
        final_args_name = Util.final_args_name(fun_name)
        scope_name = Util.scope_name(fun_name)

        {:ok,
         {:%, [line: line],
          [
            {:__aliases__, [line: line, alias: false], [:Dx, :Defd, :Fn]},
            {:%{}, [line: line],
             [
               ok?: false,
               final_args_ok?: false,
               fun:
                 {:fn, meta,
                  [
                    {:->, meta,
                     [args, {{:., meta, [module, defd_name]}, meta, args ++ [state.eval_var]}]}
                  ]},
               final_args_fun:
                 {:fn, meta,
                  [
                    {:->, meta,
                     [
                       args,
                       {{:., meta, [module, final_args_name]}, meta, args ++ [state.eval_var]}
                     ]}
                  ]},
               scope:
                 {:&, meta, [{:/, [], [{{:., meta2, [module, scope_name]}, meta3, []}, arity]}]}
             ]}
          ]}}
        |> with_state(state)

      true ->
        if state.warn_non_dx? do
          warn(meta, state, """
          #{fun_name}/#{arity} is not defined with defd.

          Either define it using defd (preferred) or wrap the call in the non_dx/1 function:

              non_dx(...(&#{module}.#{fun_name}/#{arity}))
          """)
        end

        quote line: line do
          {:ok,
           fn unquote_splicing(args) ->
             {:ok, unquote(module).unquote(fun_name)(unquote_splicing(args))}
           end}
        end
        |> with_state(%{state | called_non_dx?: true})
    end
  end

  # local_fun()
  def normalize({fun_name, meta, args} = fun, state)
      when is_atom(fun_name) and is_list(args) do
    arity = length(args)

    cond do
      {fun_name, arity} in state.defds ->
        defd_name = Util.defd_name(fun_name)

        state = Map.update!(state, :used_defds, &MapSet.put(&1, {fun_name, arity}))

        normalize_call_args(args, state, fn args ->
          {defd_name, meta, args ++ [state.eval_var]}
        end)
        |> Loader.add()

      Util.has_function?(state.module, fun_name, arity) ->
        if state.warn_non_dx? do
          warn(meta, state, """
          #{fun_name}/#{arity} is not defined with defd.

          Either define it using defd (preferred) or wrap the call in the non_dx/1 function:

              non_dx(#{fun_name}(...))
          """)
        end

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
  def normalize({{:., meta, [module, fun_name]}, meta2, args} = fun, state)
      when is_atom(fun_name) and is_list(args) do
    arity = length(args)

    cond do
      # Access.get/2
      meta2[:no_parens] ->
        case maybe_capture_loader(fun, state) do
          {:ok, loader_ast, state} ->
            Loader.add(loader_ast, state)
            |> Ast.mark_var_as_finalized()

          :error ->
            {module, state} = normalize(module, state)

            Ast.fetch(module, fun_name, meta[:line] || state.line, state)
        end

      # function call on dynamically computed module
      not is_atom(module) ->
        normalize_call_args(args, state, fn args ->
          quote do
            Dx.Defd.Runtime.maybe_call_defd(
              unquote(module),
              unquote(fun_name),
              unquote(args),
              unquote(state.eval_var)
            )
          end
        end)

      rewriter = @rewriters[module] ->
        rewriter.rewrite(fun, state)

      Util.is_defd?(module, fun_name, arity) ->
        defd_name = Util.defd_name(fun_name)

        normalize_call_args(args, state, fn args ->
          {{:., meta, [module, defd_name]}, meta2, args ++ [state.eval_var]}
        end)
        |> Loader.add()

      # avoid non_dx warning for `Dx.Scope.all/1`
      {module, fun_name, arity} == {Dx.Scope, :all, 1} ->
        normalize_external_call_args(args, state, fn args ->
          {{:., meta, [module, fun_name]}, meta2, args}
        end)
        |> Ast.ok()

      Util.has_function?(module, fun_name, arity) ->
        if state.warn_non_dx? do
          warn(meta2, state, """
          #{inspect(module)}.#{fun_name}/#{arity} is not defined with defd.

          Either define it using defd (preferred) or wrap the call in the non_dx/1 function:

              non_dx(#{inspect(module)}.#{fun_name}(...))
          """)
        end

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

  def normalize({_, meta, _} = ast, state) do
    compile_error!(meta, state, """
    This syntax is not supported yet:

    #{Macro.to_string(ast)}
    """)
  end

  def maybe_load_scope({:ok, module}, state) when is_atom(module) do
    quote do
      Dx.Scope.lookup(Dx.Scope.all(unquote(module)), unquote(state.eval_var))
    end
    |> Loader.add(state)
  end

  def maybe_load_scope({:ok, var}, state) when is_var(var) do
    quote do
      Dx.Scope.maybe_lookup(unquote(var), unquote(state.eval_var))
    end
    |> Loader.add(state)
  end

  def maybe_load_scope({:ok, {:%{}, _meta, [{:__struct__, Dx.Scope} | _]} = ast}, state) do
    quote do
      Dx.Scope.lookup(unquote(ast), unquote(state.eval_var))
    end
    |> Loader.add(state)
  end

  def maybe_load_scope({:ok, ast}, state) do
    {{:ok, ast}, state}
  end

  # for undefined variables
  def maybe_load_scope(other, state) do
    {other, state}
  end

  def add_scope_loader_for({:ok, ast}, state) do
    quote do
      Dx.Scope.maybe_lookup(unquote(ast), unquote(state.eval_var))
    end
    |> Loader.add(state)
  end

  def normalize_load_unwrap(ast, state) do
    case normalize(ast, state) do
      {{:ok, ast}, state} ->
        {ast, state}

      {ast, state} ->
        {{:ok, var}, state} = Loader.add(ast, state)

        {var, state}
    end
  end

  # Access.get/2
  def maybe_capture_loader({{:., meta, [ast, fun_name]}, meta2, []}, state)
      when is_atom(fun_name) do
    if meta2[:no_parens] do
      case maybe_capture_loader(ast, state) do
        {:ok, ast, state} ->
          {fun, state} = Ast.fetch(ast, fun_name, meta[:line] || state.line, state)

          {:ok, fun, state}

        :error ->
          :error
      end
    else
      :error
    end
  end

  def maybe_capture_loader(var, state) when is_var(var) do
    if Ast.var_id(var) in state.args do
      {var, state} = Ast.finalize(Ast.var_id(var), state)

      {:ok, {:ok, var}, state}
    else
      :error
    end
  end

  def maybe_capture_loader(_ast, _state) do
    :error
  end

  # extracts only loaders based on variables bound outside of the external anonymous function
  defp normalize_external_fn(ast, state) do
    Macro.prewalk(ast, state, fn
      {{:., _meta, [_module, fun_name]}, meta2, args} = fun, state
      when is_atom(fun_name) and is_list(args) ->
        # Access.get/2
        if meta2[:no_parens] do
          case maybe_capture_loader(fun, state) do
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

  def root_var_from_access_chain({{:., _meta, [ast, _fun_name]}, _meta2, []}) do
    root_var_from_access_chain(ast)
  end

  def root_var_from_access_chain(var) when is_var(var) do
    var
  end

  def replace_root_var({{:., meta, [ast, fun_name]}, meta2, []}, new_var) do
    {{:., meta, [replace_root_var(ast, new_var), fun_name]}, meta2, []}
  end

  def replace_root_var(var, new_var) when is_var(var) do
    new_var
  end

  def data_req_from_access_chain({{:., _meta, [ast, fun_name]}, _meta2, []}, acc) do
    acc = %{fun_name => acc}
    data_req_from_access_chain(ast, acc)
  end

  def data_req_from_access_chain(var, acc) when is_var(var) do
    acc
  end

  def normalize_external_call_args(args, state, fun) do
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
          normalize(arg, state)
      end)

    {args, new_state} = args |> Enum.map(&Ast.unwrap/1) |> finalize_args(new_state)

    do_normalize_call_args(args, new_state, fun)
  end

  def finalize_args(args, state) do
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

  def normalize_call_args(args, state, fun) do
    {args, state} = Enum.map_reduce(args, state, &normalize/2)
    do_normalize_call_args(args, state, fun)
  end

  defp do_normalize_call_args(args, state, fun) do
    args
    |> Enum.map(&Ast.unwrap/1)
    |> fun.()
    |> with_state(state)
  end

  ## Helpers

  @compile {:inline, with_state: 2}
  defp with_state(ast, state), do: {ast, state}

  def compile_error!(meta, state, description) do
    line = meta[:line] || state.line
    raise CompileError, line: line, file: state.file, description: description
  end

  def warn(meta, state, message) do
    line = meta[:line] || state.line
    {name, arity} = state.function
    entry = {state.module, name, arity, [file: String.to_charlist(state.file), line: line]}
    IO.warn(message, [entry])
  end
end
