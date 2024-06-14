defmodule Dx.Defd.Ast do
  import __MODULE__.Guards

  # def apply({ast, state}, fun) when Kernel.is_function(fun, 1), do: {fun.(ast), state}
  # def apply({ast, state}, fun) when Kernel.is_function(fun, 2), do: {fun.(ast, state), state}
  # def apply2({ast, state}, fun), do: fun.(ast, state)

  def is_function(
        {:ok,
         {:%, _,
          [
            {:__aliases__, _, [:Dx, :Defd, :Fn]},
            {:%{}, _,
             [
               {:ok?, _},
               {:fun, {:fn, _, [{:->, _, [args, _body]}]}} | _
             ]}
          ]}},
        arity
      ) do
    length(args) == arity
  end

  def is_function({:ok, {:fn, _meta, [{:->, _meta2, [args, _body]}]}}, arity) do
    length(args) == arity
  end

  def is_function({:&, _meta, [{:/, [], [{_fun_name, [], nil}, arity]}]}, arity) do
    true
  end

  def is_function({:&, _meta, [{:/, [], [{{:., [], [_mod, _fun_name]}, [], []}, arity]}]}, arity) do
    true
  end

  def is_function(_ast, _arity), do: false

  def ok({ast, state}) do
    {{:ok, ast}, state}
  end

  def ok?(ast, fn? \\ false)

  def ok?(
        {:ok,
         {:%, _,
          [
            {:__aliases__, _, [:Dx, :Defd, :Fn]},
            {:%{}, _,
             [
               {:ok?, ok?} | _
             ]}
          ]}},
        _
      ),
      do: ok?

  def ok?({:ok, {:fn, _meta, [{:->, _meta2, [_args, {:ok, _body}]}]}}, _), do: true
  def ok?({:ok, {:fn, _meta, [{:->, _meta2, [_args, _body]}]}}, _), do: false
  def ok?({:ok, _}, true), do: false
  def ok?({:ok, _}, _), do: true
  def ok?(_other, _), do: false

  def unwrap_inner({:ok, {:fn, meta, [{:->, meta2, [args, {:ok, body}]}]}}) do
    {:fn, meta, [{:->, meta2, [args, body]}]}
  end

  def unwrap_inner({:ok, other}) do
    quote do
      Dx.Defd.Fn.maybe_unwrap_ok(unquote(other))
    end
  end

  def unwrap_maybe_fn({:ok, ast}) do
    quote do
      Dx.Defd.Fn.maybe_unwrap(unquote(ast))
    end
  end

  # for undefined variables
  def unwrap_maybe_fn(other) do
    other
  end

  def unwrap({:ok, ast}) do
    ast
  end

  def wrap_args([arg]) do
    arg
  end

  def wrap_args(args) do
    List.wrap(args)
  end

  def flatten_kv_list(kv_list) do
    Enum.flat_map(kv_list, fn {k, v} -> [k, v] end)
  end

  def unflatten_kv_list(kv_list) do
    Enum.chunk_every(kv_list, 2)
    |> Enum.map(fn [k, v] -> {k, v} end)
  end

  def var_id({var_name, meta, context}) do
    {var_name, Keyword.take(meta, [:version, :counter]), context}
  end

  def cleanup({:__block__, meta, _lines} = block) do
    case cleanup_line(block) do
      [ast] -> ast
      lines -> {:__block__, meta, unwrap_lines(lines)}
    end
  end

  def cleanup(ast) do
    ast
  end

  defp cleanup_line({:__block__, _meta, lines}) do
    Enum.flat_map(lines, &cleanup_line/1)
  end

  defp cleanup_line(ast) do
    [cleanup(ast)]
  end

  defp unwrap_lines([]), do: []
  defp unwrap_lines([last_line]), do: [last_line]
  defp unwrap_lines([{:ok, line} | rest]), do: [line | unwrap_lines(rest)]
  defp unwrap_lines([line | rest]), do: [line | unwrap_lines(rest)]

  defp ensure_loaded(ast, data_reqs) do
    do_ensure_loaded(cleanup(ast), data_reqs)
  end

  defp do_ensure_loaded(ast, []) do
    ast
  end

  defp do_ensure_loaded({:ok, var}, [{loader, var}]) do
    loader
  end

  defp do_ensure_loaded(ast, [{{:ok, right}, pattern}]) do
    quote do
      {:ok, unquote(pattern) = unquote(right)}
      unquote(ast)
    end
    |> cleanup()
  end

  defp do_ensure_loaded(ast, [{loader, var}]) do
    quote do
      case unquote(loader) do
        {:ok, unquote(var)} -> unquote(ast)
        other -> other
      end
    end
  end

  defp do_ensure_loaded(ast, data_reqs) do
    {assigns, data_reqs} = Enum.split_with(data_reqs, &match?({{:ok, _}, _}, &1))

    assigns_ast =
      Enum.map(assigns, fn {right, pattern} ->
        {:=, [], [pattern, right]}
      end)

    {loaders, vars} = Enum.unzip(data_reqs)

    ast = cleanup({:__block__, [], assigns_ast ++ [ast]})

    quote do
      case Dx.Defd.Result.collect_reverse(unquote(loaders), {:ok, []}) do
        {:ok, unquote(Enum.reverse(vars))} -> unquote(ast)
        other -> other
      end
    end
  end

  def ensure_vars_loaded(ast, filter_vars, state) do
    data_vars = get_data_vars(state.data_reqs)

    # IO.puts("")
    # IO.puts("---")
    # IO.inspect(Map.keys(filter_vars), label: "filter_vars")
    # IO.inspect(Map.keys(data_vars), label: "data_vars")

    state.data_reqs
    |> Enum.split_with(fn {loader_ast, _data_var} ->
      loader_vars = collect_vars(loader_ast, %{})
      # IO.inspect(loader_vars, label: :loader_vars)
      # IO.inspect(data_var, label: :data_var)
      # r1 = any_var_in?(loader_vars, filter_vars) |> IO.inspect(label: :in_filter_vars?)
      # r2 = any_var_in?(loader_vars, data_vars) |> IO.inspect(label: :in_data_vars?)
      # p(loader_ast, "(loader)")
      # r1 and not r2
      any_var_in?(loader_vars, filter_vars) and not any_var_in?(loader_vars, data_vars)
    end)
    |> case do
      {[], _data_reqs} ->
        {ast, state}

      {local_data_reqs, other_data_reqs} ->
        next_filter_vars = get_data_vars(local_data_reqs)
        state = %{state | data_reqs: Map.new(other_data_reqs)}
        {ast, state} = ensure_vars_loaded(ast, next_filter_vars, state)
        # ast = ensure_loaded(ast, local_data_reqs, state)
        ast = ensure_loaded(ast, local_data_reqs)
        {ast, state}
    end
  end

  defp ensure_all_loaded(ast, state) do
    data_vars = get_data_vars(state.data_reqs)

    state.data_reqs
    |> Enum.split_with(fn {loader_ast, _data_var} ->
      loader_vars = collect_vars(loader_ast, %{})
      not any_var_in?(loader_vars, data_vars)
    end)
    |> case do
      {[], _data_reqs} ->
        {ast, state}

      {local_data_reqs, other_data_reqs} ->
        next_filter_vars = get_data_vars(local_data_reqs)
        state = %{state | data_reqs: Map.new(other_data_reqs)}
        {ast, state} = ensure_vars_loaded(ast, next_filter_vars, state)
        # ast = ensure_loaded(ast, local_data_reqs, state)
        ast = ensure_loaded(ast, local_data_reqs)
        {ast, state}
    end
  end

  def with_root_args(args, state, fun) do
    temp_state = Map.update!(state, :args, &collect_vars(args, &1))

    case fun.(temp_state) do
      {ast, updated_state} ->
        {ast, updated_state} = ensure_all_loaded(ast, updated_state)

        {ast, %{updated_state | args: state.args}}

      other ->
        IO.inspect(other)
        raise CompileError
    end
  end

  # merge given args into state.args for calling fun,
  # then reset state.args to its original value
  def with_args(args, state, fun) do
    new_vars = collect_vars(args, %{})
    temp_state = Map.update!(state, :args, &collect_vars(args, &1))

    case fun.(temp_state) do
      {ast, updated_state} ->
        {ast, updated_state} = ensure_vars_loaded(ast, new_vars, updated_state)

        {ast, %{updated_state | args: state.args}}
    end
  end

  def with_args_no_loaders!(args, state, fun) do
    temp_state = Map.update!(state, :args, &collect_vars(args, &1))

    case fun.(temp_state) do
      {ast, updated_state} ->
        if updated_state.data_reqs != state.data_reqs do
          raise CompileError, """
          Unallowed data requirement in code:

          #{Macro.to_string(ast)}

          Data reqs:

          #{Enum.map_join(updated_state.data_reqs, "\n", fn {ast, var} -> "#{Macro.to_string(var)} -> #{Macro.to_string(ast)}" end)}
          """
        end

        {ast, %{updated_state | args: state.args}}
    end
  end

  defp get_data_vars(data_reqs) do
    Map.new(data_reqs, fn {_loader_ast, data_var} -> {data_var, true} end)
  end

  defp any_var_in?(ast_vars, vars) do
    ast_vars
    |> Enum.any?(fn {var, _} -> Map.has_key?(vars, var) end)
  end

  def collect_vars({:%, _meta, [_type, map]}, acc) do
    collect_vars(map, acc)
  end

  def collect_vars({:%{}, _meta, pairs}, acc) do
    Enum.reduce(pairs, acc, fn {k, v}, acc ->
      acc = collect_vars(k, acc)
      collect_vars(v, acc)
    end)
  end

  def collect_vars({_, _, args}, acc) when is_list(args) do
    collect_vars(args, acc)
  end

  def collect_vars({arg0, arg1}, acc) do
    acc = collect_vars(arg0, acc)
    collect_vars(arg1, acc)
  end

  def collect_vars([ast | tail], acc) do
    acc = collect_vars(ast, acc)
    collect_vars(tail, acc)
  end

  def collect_vars(var, acc) when is_var(var) do
    Map.put(acc, var_id(var), true)
  end

  def collect_vars(_other, acc) do
    acc
  end

  def mark_vars_as_generated(ast) do
    Macro.prewalk(ast, fn
      {varname, meta, mod} when is_atom(varname) and is_atom(mod) ->
        {varname, Keyword.put(meta, :generated, true), mod}

      other ->
        other
    end)
  end

  def fetch({:ok, ast}, key, eval, line) when is_var(ast) do
    asty = {{:., [line: line], [ast, key]}, [no_parens: true, line: line], []}

    quote line: line do
      Dx.Defd.Util.fetch(unquote(ast), unquote(asty), unquote(key), unquote(eval))
    end
  end

  def fetch({:ok, ast}, key, eval, line) do
    var = Macro.unique_var(:map, __MODULE__)
    asty = {{:., [line: line], [var, key]}, [no_parens: true, line: line], []}

    {:__block__, [],
     [
       {:=, [], [var, ast]},
       {{:., [line: line],
         [{:__aliases__, [line: line, alias: false], [:Dx, :Defd, :Util]}, :fetch]}, [line: line],
        [var, asty, key, eval]}
     ]}
  end

  def fetch(ast, key, eval, line) do
    var = Macro.unique_var(:map, __MODULE__)
    asty = {{:., [line: line], [var, key]}, [no_parens: true, line: line], []}

    quote line: line do
      case unquote(ast) do
        {:ok, unquote(var)} ->
          Dx.Defd.Util.fetch(unquote(var), unquote(asty), unquote(key), unquote(eval))

        other ->
          other
      end
    end
  end

  # Helpers

  def closest_meta({_, meta, _}), do: meta
  def closest_meta([elem | _rest]), do: closest_meta(elem)
  def closest_meta({elem, _elem}), do: closest_meta(elem)
  def closest_meta(_other), do: []

  def pp({ast, state}, label \\ nil) do
    p(ast, label)
    {ast, state}
  end

  def p(ast, label \\ nil)

  def p(ast, nil) do
    IO.puts("\n\n" <> Macro.to_string(ast) <> "\n\n")
    ast
  end

  def p(ast, label) do
    IO.puts("\n\n#{label}:\n" <> Macro.to_string(ast) <> "\n\n")
    ast
  end
end
