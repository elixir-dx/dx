defmodule Dx.Defd.Ast do
  @moduledoc false

  alias Dx.Defd.Ast.Loader
  alias Dx.Defd.Ast.State

  import Dx.Defd.Ast.Guards

  def local_fun_ref({name, arity}), do: local_fun_ref(name, arity)

  def local_fun_ref(name, meta \\ [], arity, meta2 \\ []) do
    {:&, meta, [{:/, [], [{name, meta2, nil}, arity]}]}
  end

  def block(lines \\ [], meta \\ []) do
    {:__block__, meta, lines}
  end

  def is_function(
        {:ok,
         {:%, _,
          [
            {:__aliases__, _, [:Dx, :Defd, :Fn]},
            {:%{}, _,
             [
               {:ok?, _},
               {:final_args_ok?, _},
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

  def is_function({:&, _meta, [{:/, [], [{_fun_name, _meta2, nil}, arity]}]}, arity) do
    true
  end

  def is_function(
        {:&, _meta, [{:/, [], [{{:., [], [_mod, _fun_name]}, _meta2, []}, arity]}]},
        arity
      ) do
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

  def final_args_ok?(ast, fn? \\ false)

  def final_args_ok?(
        {:ok,
         {:%, _,
          [
            {:__aliases__, _, [:Dx, :Defd, :Fn]},
            {:%{}, _,
             [
               {:ok?, _ok?},
               {:final_args_ok?, final_args_ok?} | _
             ]}
          ]}},
        _
      ),
      do: final_args_ok?

  def final_args_ok?({:ok, {:fn, _meta, [{:->, _meta2, [_args, {:ok, _body}]}]}}, _), do: true
  def final_args_ok?({:ok, {:fn, _meta, [{:->, _meta2, [_args, _body]}]}}, _), do: false
  def final_args_ok?({:ok, _}, true), do: false
  def final_args_ok?({:ok, _}, _), do: true
  def final_args_ok?(_other, _), do: false

  def unwrap_inner({:ok, {:fn, meta, [{:->, meta2, [args, {:ok, body}]}]}}) do
    {:fn, meta, [{:->, meta2, [args, body]}]}
  end

  def unwrap_inner({:ok, other}) do
    quote do
      Dx.Defd.Fn.maybe_unwrap_ok(unquote(other))
    end
  end

  def unwrap_final_args_inner({:ok, {:fn, meta, [{:->, meta2, [args, {:ok, body}]}]}}) do
    {:fn, meta, [{:->, meta2, [args, body]}]}
  end

  def unwrap_final_args_inner({:ok, other}) do
    quote do
      Dx.Defd.Fn.maybe_unwrap_final_args_ok(unquote(other))
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

  def to_defd_fun({:ok, ast}) do
    quote do
      Dx.Defd.Fn.to_defd_fun(unquote(ast))
    end
  end

  # for undefined variables
  def to_defd_fun(other) do
    other
  end

  def unwrap({:ok, ast}) do
    ast
  end

  def wrap_args([arg]), do: arg
  def wrap_args(args) when is_list(args), do: args

  @doc """
  Unwraps arguments wrapped by `wrap_args/1` back to their original form.

  ## Parameters

  - `wrapped_args`: The wrapped form of the arguments.
  - `original_args`: The original structure of the arguments before wrapping.

  ## Examples

      iex> unwrap_args([:a, :b, :c], [:x, :y, :z])
      [:a, :b, :c]

      iex> unwrap_args(:a, [:x])
      [:a]

      iex> unwrap_args([], [])
      []

  """
  def unwrap_args(_wrapped_args, []), do: []
  def unwrap_args(single_arg, [_]), do: [single_arg]
  def unwrap_args(list, original_args) when is_list(original_args), do: list

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

  def strip_vars_meta(ast) do
    Macro.prewalk(ast, fn
      var when is_var(var) -> var_id(var)
      other -> other
    end)
  end

  def with_root_args(args, state, fun) do
    temp_state = Map.update!(state, :args, &collect_vars(args, &1))

    case fun.(temp_state) do
      {ast, updated_state} ->
        loaders = Loader.subtract(updated_state.loaders, state.loaders)

        updated_state = %{updated_state | loaders: loaders}

        {ast, updated_state} = Loader.ensure_all_loaded(ast, updated_state)

        {ast, %{updated_state | args: state.args, loaders: state.loaders}}

      other ->
        IO.inspect(other)
        raise CompileError
    end
  end

  def with_args_no_loaders!(args, state, fun) do
    State.pass_in(state, [args: &collect_vars(args, &1), loaders: []], fn temp_state ->
      case fun.(temp_state) do
        {ast, updated_state} ->
          if updated_state.loaders != [] do
            raise CompileError,
              file: state.file,
              line: state.line,
              description: """
              Unallowed data requirement in code:

              #{Macro.to_string(ast)}

              Data reqs:

              #{Enum.map_join(updated_state.loaders, "\n", &inspect(&1, pretty: true))}
              """
          end

          {ast, updated_state}
      end
    end)
  end

  def collect_vars(ast, acc \\ MapSet.new())

  def collect_vars(ast, acc) do
    Macro.prewalk(ast, acc, fn
      {varname, _meta, mod} = var, acc when is_atom(varname) and is_atom(mod) ->
        {var, MapSet.put(acc, var_id(var))}

      other, acc ->
        {other, acc}
    end)
    |> elem(1)
  end

  def mark_vars_as_generated(ast) do
    Macro.prewalk(ast, fn
      {varname, meta, mod} when is_atom(varname) and is_atom(mod) ->
        {varname, Keyword.put(meta, :generated, true), mod}

      other ->
        other
    end)
  end

  def mark_var_as_finalized({{:ok, var}, state}) do
    state = %{state | finalized_vars: MapSet.put(state.finalized_vars, var_id(var))}
    {{:ok, var}, state}
  end

  def fetch({:ok, ast}, key, line, state) when is_var(ast) do
    asty = {{:., [line: line], [ast, key]}, [no_parens: true, line: line], []}

    quote line: line do
      Dx.Defd.Runtime.fetch(unquote(ast), unquote(asty), unquote(key), unquote(state.eval_var))
    end
    |> with_state(state)
  end

  def fetch({:ok, ast}, key, line, state) do
    var = Macro.var(:map, __MODULE__)
    asty = {{:., [line: line], [var, key]}, [no_parens: true, line: line], []}

    {:__block__, [],
     [
       {:=, [], [var, ast]},
       {{:., [line: line],
         [{:__aliases__, [line: line, alias: false], [:Dx, :Defd, :Runtime]}, :fetch]},
        [line: line], [var, asty, key, state.eval_var]}
     ]}
    |> with_state(state)
  end

  def fetch(ast, key, line, state) do
    var = Macro.var(:map, __MODULE__)
    asty = {{:., [line: line], [var, key]}, [no_parens: true, line: line], []}

    quote line: line do
      case unquote(ast) do
        {:ok, unquote(var)} ->
          Dx.Defd.Runtime.fetch(
            unquote(var),
            unquote(asty),
            unquote(key),
            unquote(state.eval_var)
          )

        other ->
          other
      end
    end
    |> with_state(state)
  end

  def finalize({ast, state}), do: finalize(ast, state)

  def finalize(ast, state) do
    prewalk(ast, state, fn
      var, state when is_var(var) ->
        if var_id(var) in state.finalized_vars do
          {var, state}
        else
          {{:ok, var}, state} =
            quote do
              Dx.Defd.Runtime.finalize(unquote(var), unquote(state.eval_var))
            end
            |> Loader.add(state)

          {var, state}
        end

      ast, state ->
        {ast, state}
    end)
  end

  def load_scopes({ast, state}), do: load_scopes(ast, state)

  def load_scopes(ast, state) do
    prewalk(ast, state, fn
      var, state when is_var(var) ->
        if var_id(var) in state.finalized_vars do
          {var, state}
        else
          {{:ok, var}, state} =
            quote do
              Dx.Defd.Runtime.load_scopes(unquote(var), unquote(state.eval_var))
            end
            |> Loader.add(state)

          {var, state}
        end

      ast, state ->
        {ast, state}
    end)
  end

  defp prewalk(ast, acc, fun) do
    traverse(ast, acc, fun, fn x, a -> {x, a} end)
  end

  defp traverse(ast, acc, pre, post) do
    {ast, acc} = pre.(ast, acc)
    do_traverse(ast, acc, pre, post)
  end

  @ignored [:fn]
  defp do_traverse({ignore, _, _} = ast, acc, _pre, _post) when ignore in @ignored do
    {ast, acc}
  end

  defp do_traverse({:=, meta, [left, right]}, acc, pre, post) do
    {[right], acc} = do_traverse_args([right], acc, pre, post)
    post.({:=, meta, [left, right]}, acc)
  end

  defp do_traverse({form, meta, args}, acc, pre, post) when is_atom(form) do
    {args, acc} = do_traverse_args(args, acc, pre, post)
    post.({form, meta, args}, acc)
  end

  defp do_traverse({form, meta, args}, acc, pre, post) do
    {form, acc} = pre.(form, acc)
    {form, acc} = do_traverse(form, acc, pre, post)
    {args, acc} = do_traverse_args(args, acc, pre, post)
    post.({form, meta, args}, acc)
  end

  defp do_traverse({left, right}, acc, pre, post) do
    {left, acc} = pre.(left, acc)
    {left, acc} = do_traverse(left, acc, pre, post)
    {right, acc} = pre.(right, acc)
    {right, acc} = do_traverse(right, acc, pre, post)
    post.({left, right}, acc)
  end

  defp do_traverse(list, acc, pre, post) when is_list(list) do
    {list, acc} = do_traverse_args(list, acc, pre, post)
    post.(list, acc)
  end

  defp do_traverse(x, acc, _pre, post) do
    post.(x, acc)
  end

  defp do_traverse_args(args, acc, _pre, _post) when is_atom(args) do
    {args, acc}
  end

  defp do_traverse_args(args, acc, pre, post) when is_list(args) do
    :lists.mapfoldl(
      fn x, acc ->
        {x, acc} = pre.(x, acc)
        do_traverse(x, acc, pre, post)
      end,
      acc,
      args
    )
  end

  # Helpers

  @compile {:inline, with_state: 2}
  defp with_state(ast, state), do: {ast, state}

  def closest_meta({_, meta, _}), do: meta
  def closest_meta([elem | _rest]), do: closest_meta(elem)
  def closest_meta({elem, _elem}), do: closest_meta(elem)
  def closest_meta(_other), do: []

  def to_s(ast) do
    ast
    |> Code.quoted_to_algebra(syntax_colors: Application.fetch_env!(:elixir, :ansi_syntax_colors))
    |> Inspect.Algebra.format(98)
    |> IO.iodata_to_binary()
  end

  def pp({ast, state}, label \\ nil) do
    p(ast, label)
    {ast, state}
  end

  def p(ast, label \\ nil)

  def p(ast, nil) do
    IO.puts("\n\n" <> to_s(ast) <> "\n\n")
    ast
  end

  def p(ast, label) do
    IO.puts("\n\n#{label}:\n" <> to_s(ast) <> "\n\n")
    ast
  end

  def p_raw(ast, label \\ nil) do
    formatted = Macro.to_string(ast)
    output = "\n\n#{formatted}\n\n"

    case label do
      nil -> IO.puts(output)
      label -> IO.puts("\n\n#{label}:\n#{formatted}\n\n")
    end

    ast
  end
end
