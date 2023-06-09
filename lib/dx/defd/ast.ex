defmodule Dx.Defd.Ast do
  defguardp is_var(var)
            when is_tuple(var) and tuple_size(var) == 3 and is_atom(elem(var, 0)) and
                   is_atom(elem(var, 2))

  def ensure_loaded(ast, data_reqs) do
    {loaders, vars} = Enum.unzip(data_reqs)
    ensure_loaded(ast, loaders, vars)
  end

  def ensure_loaded(ast, [], _vars) do
    ast
  end

  def ensure_loaded(ast, [loader], [var]) do
    quote do
      case unquote(loader) do
        {:ok, unquote(var)} -> unquote(ast)
        other -> other
      end
    end
  end

  def ensure_loaded(ast, list, vars) do
    quote do
      case Dx.Defd.Result.collect_reverse(unquote(list), {:ok, []}) do
        {:ok, unquote(Enum.reverse(vars))} -> unquote(ast)
        other -> other
      end
    end
  end

  def unwrap({:ok, ast}) do
    ast
  end

  def unwrap(ast) do
    quote do
      Dx.Result.unwrap!(unquote(ast))
    end
  end

  def wrap_args([arg]) do
    arg
  end

  def wrap_args(args) do
    List.wrap(args)
  end

  # merge given args into state.args for calling fun,
  # then reset state.args to its original value
  def with_args(args, state, fun) do
    temp_state = Map.update!(state, :args, &collect_vars(args, &1))

    case fun.(temp_state) do
      {ast, updated_state} -> {ast, %{updated_state | args: state.args}}
    end
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

  def collect_vars({var_name, _meta, context} = var, acc)
      when is_atom(var_name) and is_atom(context) do
    Map.put(acc, var_name, var)
  end

  def collect_vars([ast | tail], acc) do
    acc = collect_vars(ast, acc)
    collect_vars(tail, acc)
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
end
