defmodule Dx.Defd.Compiler do
  alias Dx.Defd.Ast
  alias Dx.Defd.Util

  import Ast.Guards

  @rewriters %{
    Enum => Dx.Enum,
    :erlang => Dx.Defd.Kernel,
    Kernel => Dx.Defd.Kernel
  }

  # @queryables Protocol.extract_impls(Ecto.Queryable)

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
      var_index: 1,
      scope_args: [],
      eval_var: eval_var,
      in_call?: false,
      in_scope?: false,
      is_loader?: false,
      data_reqs: %{},
      # scopable_data_reqs: MapSet.new(),
      scope_safe_vars: MapSet.new(),
      external_vars: %{},
      rewrite_underscore?: false
    }

    quoted = Enum.flat_map(exports, &compile_each_defd(&1, state))

    {:__block__, [], quoted}
  end

  defp compile_prepare_arities(definitions) do
    for {{name, arity}, %{defaults: defaults}} <- definitions,
        arity <- (arity - map_size(defaults))..arity,
        into: MapSet.new(),
        do: {name, arity}
  end

  defp compile_each_defd({{name, arity} = def, def_meta}, state) do
    %{defaults: defaults, opts: opts} = def_meta

    all_args = Macro.generate_arguments(arity, __MODULE__)
    state = Map.put(state, :all_args, all_args)

    {{kind, meta, args, ast}, scope_ast, state} = get_and_normalize_defd_and_scope(def, state)

    defd_name = Util.defd_name(name)
    scope_name = Util.scope_name(name)

    scope_args =
      Enum.with_index(args, fn arg, i ->
        case defaults do
          %{^i => {meta, default}} -> {:\\, meta, [arg, default]}
          %{} -> arg
        end
      end)

    defd_args = scope_args ++ [state.eval_var]

    entrypoints =
      case Keyword.get(opts, :def, :warn) do
        :warn ->
          Module.delete_definition(state.module, def)

          quote line: state.line do
            Kernel.unquote(kind)(unquote(name)(unquote_splicing(all_args))) do
              IO.warn("""
              Use Dx.load as entrypoint.
              """)

              Dx.Defd.load!(unquote(name)(unquote_splicing(all_args)))
            end
          end
          |> strip_definition_context()
          |> List.wrap()

        :no_warn ->
          Module.delete_definition(state.module, def)

          quote line: state.line do
            Kernel.unquote(kind)(unquote(name)(unquote_splicing(all_args))) do
              Dx.Defd.load!(unquote(name)(unquote_splicing(all_args)))
            end
          end
          |> strip_definition_context()
          |> List.wrap()

        false ->
          Module.delete_definition(state.module, def)
          []

        :original ->
          []

        invalid ->
          compile_error!(meta, state, "Invalid option @dx def: #{inspect(invalid)}")
      end

    scope =
      quote line: state.line do
        Kernel.unquote(kind)(unquote(scope_name)(unquote_splicing(scope_args))) do
          unquote(scope_ast)
        end
      end

    defd =
      quote line: state.line do
        Kernel.unquote(kind)(unquote(defd_name)(unquote_splicing(defd_args))) do
          unquote(ast)
        end
      end

    entrypoints ++ [scope, defd]
  end

  # If the definition has a context, we don't warn when it goes unused,
  # so we remove the context as we want to keep the original semantics.
  defp strip_definition_context({kind, meta, [signature, block]}) do
    {kind, meta, [Macro.update_meta(signature, &Keyword.delete(&1, :context)), block]}
  end

  defp get_and_normalize_defd_and_scope({name, arity} = def, state) do
    {:v1, kind, meta, clauses} = Module.get_definition(state.module, def)
    # |> IO.inspect(label: "ORIG #{name}/#{arity}\n")

    state = %{state | function: def, line: meta[:line] || state.line, rewrite_underscore?: true}

    type_str = if kind == :def, do: "defd", else: "defdp"

    case clauses do
      [] ->
        compile_error!(meta, state, "cannot have #{type_str} #{name}/#{arity} without clauses")

      [{meta, args, [], ast}] ->
        # Ast.p(ast, "ORIG #{name}/#{arity}")
        # IO.puts("ORIG #{name}/#{arity}:\n" <> inspect(ast, pretty: true, limit: 100) <> "\n")

        {scope_ast, _state} = Dx.Scope.Compiler.normalize(ast, state)
        args = Ast.mark_vars_as_generated(args)

        {ast, state} =
          Ast.with_root_args(args, state, fn state ->
            normalize(ast, %{state | rewrite_underscore?: false})
          end)

        # |> load_scope()

        # IO.puts("NORM #{name}/#{arity}:\n" <> inspect(ast, pretty: true, limit: 100) <> "\n")
        Ast.p(ast, "CODE #{name}/#{arity}")
        Ast.p(scope_ast, "SCOPE #{name}/#{arity}")

        {{kind, meta, args, ast}, scope_ast, state}

      [{meta, _args, _, _} | _] = clauses ->
        case_clauses =
          Enum.map(clauses, fn {meta, args, [], ast} ->
            # Ast.p(ast, "ORIG #{name}/#{arity}")
            # IO.puts("ORIG #{name}/#{arity}:\n" <> inspect(ast, pretty: true, limit: 100) <> "\n")
            {:->, meta, [[Ast.wrap_args(args)], ast]}
          end)

        line = meta[:line] || state.line
        case_ast = {:case, [line: line], [Ast.wrap_args(state.all_args), [do: case_clauses]]}

        {ast, state} =
          Ast.with_root_args(state.all_args, state, fn state ->
            Dx.Defd.Case.normalize(case_ast, state)
          end)

        # IO.puts("NORM #{name}/#{arity}:\n" <> inspect(ast, pretty: true, limit: 100) <> "\n")
        Ast.p(ast, "CODE #{name}/#{arity}")

        {{kind, meta, state.all_args, ast}, state}
    end
  end

  def normalize_scope_safe_arg({:fn, _meta, [{:->, _meta2, [args, _body]}]} = ast, state) do
    vars = Ast.collect_vars(args, %{}) |> Map.keys() |> Enum.into(MapSet.new())
    all_vars = MapSet.union(state.scope_safe_vars, vars)
    new_vars = MapSet.difference(all_vars, state.scope_safe_vars)

    {ast, new_state} = normalize(ast, %{state | scope_safe_vars: all_vars})

    {ast, %{new_state | scope_safe_vars: MapSet.difference(new_state.scope_safe_vars, new_vars)}}
  end

  def normalize_scope_safe_arg(ast, state) do
    normalize(ast, state)
  end

  # def normalize(atom, state) when is_atom(atom) do
  #   ast =
  #     case Code.ensure_loaded(atom) do
  #       {:module, module} -> Macro.escape(Dx.Scope.all(module))
  #       {:error, _atom} -> atom
  #     end

  #   ast = {:ok, ast}
  #   {ast, state}
  # end

  def normalize(ast, state) when is_simple(ast) do
    ast = if state.in_scope?, do: {:ok, {:value, ast}}, else: {:ok, ast}
    {ast, state}
  end

  # []
  def normalize([], state) do
    {{:ok, []}, state}
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

    ast =
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

    {ast, state}
  end

  # {_, _}
  def normalize({elem_0, elem_1}, state) do
    ast = [elem_0, elem_1]
    {ast, state} = Enum.map_reduce(ast, state, &normalize/2)

    ast =
      case Dx.Defd.Result.collect_ok(ast) do
        {:ok, [elem_0, elem_1]} ->
          # unwrapped at compile-time
          {:ok, {elem_0, elem_1}}

        :error ->
          # unwrap at runtime
          quote do
            Dx.Defd.Result.collect(unquote(ast))
            |> Dx.Defd.Result.transform(fn [e0, e1] -> {e0, e1} end)
          end
      end

    {ast, state}
  end

  # {...}
  def normalize({:{}, meta, elems}, state) do
    {ast, state} = Enum.map_reduce(elems, state, &normalize/2)

    ast =
      case Dx.Defd.Result.collect_ok(ast) do
        {:ok, list} ->
          # unwrapped at compile-time
          {:ok, {:{}, meta, list}}

        :error ->
          # unwrap at runtime
          line = meta[:line] || state.line

          quote line: line do
            Dx.Defd.Result.collect(unquote(ast))
            |> Dx.Defd.Result.transform(&List.to_tuple/1)
          end
      end

    {ast, state}
  end

  # %{...}
  def normalize({:%{}, meta, pairs}, state) do
    {flat_ast, state} = pairs |> Ast.flatten_kv_list() |> Enum.map_reduce(state, &normalize/2)

    ast =
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

    {ast, state}
  end

  def normalize(var, state) when is_var(var) do
    # if state.in_scope? do
    #   {var, state}
    # else
    maybe_load_scope({:ok, var}, state)
    # end
  end

  def normalize({:call, _meta, [ast]}, state) do
    {ast, new_state} = normalize(ast, %{state | in_call?: true})
    {ast, %{new_state | in_call?: state.in_call?}}
  end

  def normalize({:fn, meta, [{:->, meta2, [args, body]}]}, state) do
    normalize_fn({:fn, meta, [{:->, meta2, [args, body]}]}, true, state)
  end

  def normalize_fn({:fn, meta, [{:->, meta2, [args, body]}]}, true, state) do
    args = Ast.mark_vars_as_generated(args)

    # Ast.with_args(args, state, fn state ->
    {scope_body, _new_state} =
      Dx.Scope.Compiler.normalize(body, Map.put(state, :scope_args, args))

    # end)

    # {scope_body, _state} = Dx.Scope.Compiler.normalize(body, Map.put(state, :scope_args, args))
    # {scope_body, _state} = Dx.Scope.Compiler.normalize(body, state)
    # {scope_body, _state} = normalize(body, %{state | in_scope?: true})

    {body, new_state} =
      Ast.with_args(args, state, fn state ->
        normalize(body, state)
      end)

    {ok?, ok_body} =
      case body do
        {:ok, ok_body} -> {true, ok_body}
        _ -> {false, nil}
      end

    line = meta[:line] || state.line

    ast =
      {:ok,
       {:%, [line: line],
        [
          {:__aliases__, [line: line, alias: false], [:Dx, :Defd, :Fn]},
          {:%{}, [line: line],
           [
             ok?: ok?,
             fun: {:fn, meta, [{:->, meta2, [args, body]}]},
             ok_fun: ok? && {:fn, meta, [{:->, meta2, [args, ok_body]}]},
             scope: {:fn, meta, [{:->, meta2, [args, scope_body]}]}
           ]}
        ]}}

    {ast, new_state}
  end

  def normalize_fn({:fn, meta, [{:->, meta2, [args, body]}]}, false, state) do
    # {body, new_state} =
    #   Ast.with_args(args, state, fn state ->
    #     normalize(body, state)
    #   end)

    # {ok?, ok_body} =
    #   case body do
    #     {:ok, ok_body} -> {true, ok_body}
    #     _ -> {false, nil}
    #   end

    # line = meta[:line] || state.line

    # ast =
    #   {:ok,
    #    {:%, [line: line],
    #     [
    #       {:__aliases__, [line: line, alias: false], [:Dx, :Defd, :Fn]},
    #       {:%{}, [line: line],
    #        [
    #          ok?: ok?,
    #          fun: {:fn, meta, [{:->, meta2, [args, body]}]},
    #          ok_fun: ok? && {:fn, meta, [{:->, meta2, [args, ok_body]}]}
    #        ]}
    #     ]}}

    # {ast, new_state}
    {body, new_state} =
      Ast.with_root_args(args, state, fn state ->
        normalize(body, state)
      end)

    ast = {:fn, meta, [{:->, meta2, [args, body]}]}
    {ast, new_state}
  end

  # fun.()
  def normalize({{:., meta, [module]}, meta2, args}, state) do
    {module, state} = normalize(module, state)
    module = Ast.unwrap(module)

    normalize_call_args(args, state, fn args ->
      {{:., meta, [module]}, meta2, args}
    end)
    |> Ast.ok()
  end

  def normalize({:case, _meta, _args} = ast, state) do
    Dx.Defd.Case.normalize(ast, state)
  end

  def normalize({:__block__, _meta, _lines} = ast, state) do
    Dx.Defd.Block.normalize(ast, state)
  end

  def normalize({:=, _meta, [_pattern, _right]} = ast, state) do
    Dx.Defd.Block.normalize(ast, state)
  end

  # &local_fun/2
  def normalize({:&, meta, [{:/, [], [{fun_name, [], nil}, arity]}]}, state) do
    args = Macro.generate_arguments(arity, __MODULE__)
    line = meta[:line] || state.line

    ast =
      if {fun_name, arity} in state.defds do
        defd_name = Util.defd_name(fun_name)
        scope_name = Util.scope_name(fun_name)

        {:ok,
         {:%, [line: line],
          [
            {:__aliases__, [line: line, alias: false], [:Dx, :Defd, :Fn]},
            {:%{}, [line: line],
             [
               ok?: false,
               fun:
                 {:fn, meta, [{:->, meta, [args, {defd_name, meta, args ++ [state.eval_var]}]}]},
               scope: {:fn, meta, [{:->, meta, [args, {scope_name, meta, args}]}]}
             ]}
          ]}}
      else
        if not state.in_call? do
          warn(meta, state, """
          #{fun_name}/#{arity} is not defined with defd.

          Either define it using defd (preferred) or wrap the call in the call/1 function:

              call(...(&#{fun_name}/#{arity}))
          """)
        end

        quote line: line do
          {:ok,
           fn unquote_splicing(args) ->
             {:ok, unquote(fun_name)(unquote_splicing(args))}
           end}
        end
      end

    {ast, state}
  end

  # &Mod.fun/3
  def normalize(
        {:&, meta, [{:/, [], [{{:., [], [module, fun_name]}, [], []}, arity]}]} = fun,
        state
      ) do
    args = Macro.generate_arguments(arity, __MODULE__)
    line = meta[:line] || state.line

    cond do
      rewriter = @rewriters[module] ->
        rewriter.rewrite(fun, state)

      Util.is_defd?(module, fun_name, arity) ->
        defd_name = Util.defd_name(fun_name)

        ast =
          quote line: line do
            {:ok,
             fn unquote_splicing(args) ->
               unquote(module).unquote(defd_name)(unquote_splicing(args), unquote(state.eval_var))
             end}
          end

        {ast, state}

      true ->
        if not state.in_call? do
          warn(meta, state, """
          #{fun_name}/#{arity} is not defined with defd.

          Either define it using defd (preferred) or wrap the call in the call/1 function:

              call(...(&#{module}.#{fun_name}/#{arity}))
          """)
        end

        ast =
          quote line: line do
            {:ok,
             fn unquote_splicing(args) ->
               {:ok, unquote(module).unquote(fun_name)(unquote_splicing(args))}
             end}
          end

        {ast, state}
    end
  end

  # local_fun()
  def normalize({fun_name, meta, args} = fun, state)
      when is_atom(fun_name) and is_list(args) do
    arity = length(args)

    cond do
      state.in_scope? and {fun_name, arity} in state.defds ->
        scope_name = Util.scope_name(fun_name)

        {args, state} = Enum.map_reduce(args, state, &normalize/2)

        {scope_name, meta, args}
        |> with_state(state)

      state.in_scope? ->
        {:error, state}

      {fun_name, arity} in state.defds ->
        defd_name = Util.defd_name(fun_name)

        {loader, state} =
          normalize_call_args(args, state, fn args ->
            {defd_name, meta, args ++ [state.eval_var]}
          end)

        data_reqs = Map.put_new(state.data_reqs, loader, Macro.unique_var(:data, __MODULE__))
        var = data_reqs[loader]
        ast = {:ok, var}

        {ast, %{state | data_reqs: data_reqs}}

      Util.has_function?(state.module, fun_name, arity) ->
        if not state.in_call? do
          warn(meta, state, """
          #{fun_name}/#{arity} is not defined with defd.

          Either define it using defd (preferred) or wrap the call in the call/1 function:

              call(#{fun_name}(...))
          """)
        end

        normalize_external_call_args(args, state, fn args ->
          {fun_name, meta, args}
        end)
        |> Ast.ok()

      true ->
        {fun, state}
    end
  end

  def normalize({{:., meta, [:erlang, :==]}, _meta2, [left, right]}, %{in_scope?: true} = state) do
    {left, state} = normalize(left, state)
    dbg(left)
    {right, state} = normalize(right, state)
    dbg(right)

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

  # Mod.fun()
  def normalize({{:., meta, [module, fun_name]}, meta2, args} = fun, state)
      when is_atom(fun_name) and is_list(args) do
    arity = length(args)

    cond do
      # Access.get/2
      state.in_scope? and meta2[:no_parens] ->
        {module, state} = normalize(module, state)

        quote line: meta[:line] do
          {:ok, Dx.Scope.field_or_assoc(unquote(module), unquote(fun_name))}
        end
        |> with_state(state)

      meta2[:no_parens] ->
        case maybe_capture_loader(fun, state) |> dbg() do
          {:ok, loader_ast, state} ->
            add_loader(loader_ast, state)
            |> mark_scope_safe()

          # {loader_ast, state}

          :error ->
            {module, state} = normalize(module, state)

            fun = Ast.fetch(module, fun_name, state.eval_var, meta[:line] || state.line)

            {fun, state}
        end

      # function call on dynamically computed module
      not is_atom(module) ->
        normalize_call_args(args, state, fn args ->
          quote do
            Dx.Defd.Util.maybe_call_defd(
              unquote(module),
              unquote(fun_name),
              unquote(args),
              unquote(state.eval_var)
            )
          end
        end)

      rewriter = @rewriters[module] ->
        cond do
          state.in_scope? and Util.is_scopable?(rewriter, fun_name, arity) ->
            {args, state} = Enum.map_reduce(args, state, &normalize/2)

            {{:., meta, [rewriter, fun_name]}, meta2, args}
            |> with_state(state)

          state.in_scope? ->
            {:error, state}

          true ->
            rewriter.rewrite(fun, state)
        end

      # case rewriter.rewrite(fun, state) do
      #   {{:ok, result}, state} ->
      #     {{:ok, result}, state}

      #   {loader, state} ->
      #     add_loader(loader, state)
      #     # |> mark_scope_safe()
      # end

      state.in_scope? and Util.is_defd?(module, fun_name, arity) ->
        scope_name = Util.scope_name(fun_name)

        {{:., meta, [module, scope_name]}, meta2, args}
        |> with_state(state)

      state.in_scope? ->
        {:error, state}

      Util.is_defd?(module, fun_name, arity) ->
        defd_name = Util.defd_name(fun_name)

        normalize_call_args(args, state, fn args ->
          {{:., meta, [module, defd_name]}, meta2, args ++ [state.eval_var]}
        end)
        |> add_loader()

      Util.has_function?(module, fun_name, arity) ->
        if not state.in_call? do
          warn(meta2, state, """
          #{inspect(module)}.#{fun_name}/#{arity} is not defined with defd.

          Either define it using defd (preferred) or wrap the call in the call/1 function:

              call(#{inspect(module)}.#{fun_name}(...))
          """)
        end

        normalize_external_call_args(args, state, fn args ->
          {{:., meta, [module, fun_name]}, meta2, args}
        end)
        |> Ast.ok()

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

  def normalize({_, meta, _} = ast, state) do
    compile_error!(meta, state, """
    This syntax is not supported yet:

    #{Macro.to_string(ast)}
    """)
  end

  def load_scope({ast, state}) do
    ast =
      quote do
        Dx.Scope.maybe_load(unquote(ast), unquote(state.eval_var))
      end

    {ast, state}
  end

  def maybe_load_scope(ast, %{in_scope?: true} = state) do
    {ast, state}
  end

  def maybe_load_scope({:ok, module}, state) when is_atom(module) do
    quote do
      Dx.Scope.lookup(Dx.Scope.all(unquote(module)), unquote(state.eval_var))
    end
    |> add_loader(state)
    |> mark_scope_safe()
  end

  def maybe_load_scope({:ok, var}, state) when is_var(var) do
    var_id = Ast.var_id(var)

    if var_id in state.scope_safe_vars do
      {{:ok, var}, state}
    else
      quote do
        Dx.Scope.maybe_lookup(unquote(var), unquote(state.eval_var))
      end
      |> add_loader(state)
      |> mark_scope_safe()
    end
  end

  def maybe_load_scope({:ok, {:%{}, _meta, [{:__struct__, Dx.Scope} | _]} = ast}, state) do
    quote do
      Dx.Scope.lookup(unquote(ast), unquote(state.eval_var))
    end
    |> add_loader(state)
    |> mark_scope_safe()
  end

  def maybe_load_scope({:ok, ast}, state) do
    {{:ok, ast}, state}
  end

  # for undefined variables
  def maybe_load_scope(other, state) do
    {other, state}
  end

  def mark_scope_safe({{:ok, var}, state}) do
    state = Map.update!(state, :scope_safe_vars, &MapSet.put(&1, var))
    {{:ok, var}, state}
  end

  # def add_scope_loader_for(ast, state) do
  #   quote do
  #     Dx.Scope.maybe_lookup(unquote(ast), unquote(state.eval_var))
  #   end
  #   |> add_loader(state, true)
  # end

  def add_loader({loader, state}), do: add_loader(loader, state)

  def add_loader(loader, state) do
    if var = Map.get(state.data_reqs, loader) do
      ast = {:ok, var}

      {ast, state}
    else
      var = Macro.var(:"dx#{state.var_index}", __MODULE__)
      data_reqs = Map.put(state.data_reqs, loader, var)
      ast = {:ok, var}

      {ast, %{state | data_reqs: data_reqs, var_index: state.var_index + 1}}
    end
  end

  # def add_loader(loader, state, scopable? \\ false)

  # def add_loader(loader, state, true) do
  #   data_reqs = Map.put_new(state.data_reqs, loader, Macro.unique_var(:data, __MODULE__))

  #   var = data_reqs[loader]
  #   ast = {:ok, var}

  #   {ast, %{state | data_reqs: data_reqs}}
  # end

  # def add_loader(loader, state, false) do
  #   {{:ok, inner_var}, state} = add_loader(loader, state, true)

  #   quote do
  #     Dx.Scope.maybe_lookup(unquote(inner_var), unquote(state.eval_var))
  #   end
  #   |> add_loader(state, true)
  # end

  # Access.get/2
  def maybe_capture_loader({{:., meta, [ast, fun_name]}, meta2, []}, state)
      when is_atom(fun_name) do
    if meta2[:no_parens] do
      case maybe_capture_loader(ast, state) do
        {:ok, ast, state} ->
          # loader_ast = Ast.fetch(ast, fun_name, state.eval_var, meta[:line] || state.line)

          # state =
          #   Map.update!(state, :data_reqs, fn data_reqs ->
          #     Map.put_new(data_reqs, loader_ast, Macro.unique_var(:data, __MODULE__))
          #   end)

          # var = state.data_reqs[loader_ast]
          # ast = {:ok, var}

          # {:ok, ast, state}

          fun = Ast.fetch(ast, fun_name, state.eval_var, meta[:line] || state.line)
          {:ok, fun, state}

        :error ->
          :error
      end
    else
      :error
    end
  end

  def maybe_capture_loader(var, state) when is_var(var) do
    if Map.has_key?(state.external_vars, Ast.var_id(var)) do
      :error
    else
      {ast, state} = maybe_load_scope({:ok, var}, state)
      {:ok, ast, state}
    end
  end

  def maybe_capture_loader(_ast, _state) do
    :error
  end

  # extracts only loaders based on variables bound outside of the external anonymous function
  defp normalize_external_fn(ast, state) do
    Macro.prewalk(ast, state, fn
      # TODO: add all other syntaxes that can bind variables
      {:fn, _meta, [{:->, _meta2, [args, _body]}]} = fun, state ->
        state = Map.update!(state, :external_vars, &Ast.collect_vars(args, &1))
        {fun, state}

      {{:., _meta, [_module, fun_name]}, meta2, args} = fun, state
      when is_atom(fun_name) and is_list(args) ->
        # Access.get/2
        if meta2[:no_parens] do
          case maybe_capture_loader(fun, state) do
            {:ok, _loader_ast, state} ->
              subject = root_var_from_access_chain(fun)
              data_req = data_req_from_access_chain(fun, %{})

              loader_ast =
                quote do
                  Dx.Defd.Util.fetch(
                    unquote(subject),
                    unquote(Macro.escape(data_req)),
                    unquote(state.eval_var)
                  )
                end

              state =
                Map.update!(state, :data_reqs, fn data_reqs ->
                  Map.put_new(data_reqs, loader_ast, Macro.unique_var(:data, __MODULE__))
                end)

              var = state.data_reqs[loader_ast]
              access_ast = replace_root_var(fun, var)

              {access_ast, state}

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
          state = Map.put(state, :external_vars, Ast.collect_vars(args, %{}))
          {body, new_state} = normalize_external_fn(body, state)

          ast = {:ok, {:fn, meta, [{:->, meta2, [args, body]}]}}
          {ast, new_state}

        {:&, _meta, [{:/, [], [{{:., [], [_mod, _fun_name]}, [], []}, _arity]}]} = fun, state ->
          {{:ok, fun}, state}

        {:&, _meta, [{:/, [], [{_fun_name, [], nil}, _arity]}]} = fun, state ->
          {{:ok, fun}, state}

        arg, state ->
          normalize(arg, state)
      end)

    do_normalize_call_args(args, new_state, fun)
  end

  def normalize_call_args(args, state, fun) do
    {args, state} = Enum.map_reduce(args, state, &normalize/2)
    do_normalize_call_args(args, state, fun)
  end

  defp do_normalize_call_args(args, state, fun) do
    call_args = args |> Enum.map(&Ast.unwrap/1) |> fun.()

    {call_args, state}
  end

  ## Helpers

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
