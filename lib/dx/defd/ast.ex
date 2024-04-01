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

  # defp ensure_loaded({:ok, var}, [{loader, var}], state) do
  #   maybe_scopable(loader, state)
  # end

  # defp ensure_loaded(ast, [{loader, var}], state) do
  #   quote do
  #     case unquote(maybe_scopable(loader, state)) do
  #       {:ok, unquote(var)} -> unquote(ast)
  #       other -> other
  #     end
  #   end
  # end

  # defp ensure_loaded(ast, data_reqs, state) do
  #   {loaders, vars} = Enum.unzip(data_reqs)

  #   loaders = Enum.map(loaders, &maybe_scopable(&1, state))

  #   quote do
  #     case Dx.Defd.Result.collect_reverse(unquote(loaders), {:ok, []}) do
  #       {:ok, unquote(Enum.reverse(vars))} -> unquote(ast)
  #       other -> other
  #     end
  #   end
  # end

  defp ensure_loaded(ast, []) do
    ast
  end

  defp ensure_loaded({:ok, var}, [{loader, var}]) do
    loader
  end

  defp ensure_loaded(ast, [{loader, var}]) do
    quote do
      case unquote(loader) do
        {:ok, unquote(var)} -> unquote(ast)
        other -> other
      end
    end
  end

  defp ensure_loaded(ast, data_reqs) do
    {loaders, vars} = Enum.unzip(data_reqs)

    quote do
      case Dx.Defd.Result.collect_reverse(unquote(loaders), {:ok, []}) do
        {:ok, unquote(Enum.reverse(vars))} -> unquote(ast)
        other -> other
      end
    end
  end

  defp scopable(loader, state) do
    quote do
      Dx.Scope.maybe_lookup(unquote(loader), unquote(state.eval_var))
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
