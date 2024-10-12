defmodule Dx.Defd.Ast.Loader do
  @moduledoc false

  alias Dx.Defd.Ast

  defstruct [
    :ast,
    :clean_ast,
    :vars,
    :data_var,
    :data_vars
  ]

  def add({ast, state}), do: add(ast, state)

  def add(ast, state) do
    clean_ast = Ast.strip_vars_meta(ast)

    if loader = Enum.find(state.loaders, &(&1.clean_ast == clean_ast)) do
      {:ok, loader.data_var}
      |> with_state(state)
    else
      var = Macro.var(:"dx#{state.var_index}", __MODULE__)

      loader = %Ast.Loader{
        ast: ast,
        clean_ast: clean_ast,
        vars: Ast.collect_vars(ast),
        data_var: var,
        data_vars: MapSet.new([var])
      }

      {:ok, var}
      |> with_state(%{state | loaders: [loader | state.loaders], var_index: state.var_index + 1})
    end
  end

  def add_assign(state, var, right) do
    clean_right = Ast.strip_vars_meta(right)

    loader = %Ast.Loader{
      ast: {:ok, right},
      clean_ast: {:ok, clean_right},
      vars: Ast.collect_vars(right),
      data_var: var,
      data_vars: Ast.collect_vars(var)
    }

    %{state | loaders: [loader | state.loaders]}
  end

  def subtract(loaders1, loaders2) do
    Enum.reject(loaders1, fn loader ->
      Enum.any?(loaders2, &(&1.clean_ast == loader.clean_ast))
    end)
  end

  defp data_vars(loaders, acc \\ MapSet.new())
  defp data_vars([], acc), do: acc
  defp data_vars([loader | rest], acc), do: data_vars(rest, MapSet.union(acc, loader.data_vars))

  def ensure_vars_loaded(ast, filter_vars, state) do
    data_vars = data_vars(state.loaders)

    state.loaders
    |> Enum.split_with(fn loader ->
      not MapSet.disjoint?(loader.vars, filter_vars) and MapSet.disjoint?(loader.vars, data_vars)
    end)
    |> case do
      {[], _loaders} ->
        {ast, state}

      {local_loaders, other_loaders} ->
        next_filter_vars = data_vars(local_loaders)
        state = %{state | loaders: other_loaders}
        {ast, state} = ensure_vars_loaded(ast, next_filter_vars, state)
        ast = ensure_loaded(ast, local_loaders)
        {ast, state}
    end
  end

  def ensure_all_loaded(ast, state) do
    data_vars = data_vars(state.loaders)

    state.loaders
    |> Enum.split_with(fn loader ->
      MapSet.disjoint?(loader.vars, data_vars)
    end)
    |> case do
      {[], _loaders} ->
        {ast, state}

      {local_loaders, other_loaders} ->
        state = %{state | loaders: other_loaders}
        {ast, state} = ensure_all_loaded(ast, state)
        ast = ensure_loaded(ast, local_loaders)
        {ast, state}
    end
  end

  def with_new_loaders_loaded(state, fun) do
    case fun.(state) do
      {ast, updated_state} ->
        new_loaders = subtract(updated_state.loaders, state.loaders)
        updated_state = %{updated_state | loaders: new_loaders}
        {ast, updated_state} = ensure_all_loaded(ast, updated_state)

        {ast, %{updated_state | loaders: state.loaders}}

      other ->
        IO.inspect(other)
        raise CompileError
    end
  end

  defp ensure_loaded(ast, loaders) do
    ast |> cleanup() |> do_ensure_loaded(loaders)
  end

  defp do_ensure_loaded(ast, []) do
    ast
  end

  defp do_ensure_loaded({:ok, var}, [%{data_var: var} = loader]) do
    loader.ast
  end

  defp do_ensure_loaded(ast, [%{ast: {:ok, right}} = loader]) do
    quote do
      {:ok, unquote(loader.data_var) = unquote(right)}
      unquote(ast)
    end
    |> cleanup()
  end

  defp do_ensure_loaded(ast, [loader]) do
    quote do
      case unquote(loader.ast) do
        {:ok, unquote(loader.data_var)} -> unquote(ast)
        other -> other
      end
    end
  end

  defp do_ensure_loaded(ast, loaders) do
    {assigns, loaders} = Enum.split_with(loaders, &match?(%{ast: {:ok, _}}, &1))

    assigns_ast =
      Enum.map(assigns, fn %{ast: {:ok, right}} = loader ->
        {:ok, {:=, [], [loader.data_var, right]}}
      end)

    ast = cleanup({:__block__, [], assigns_ast ++ [ast]})

    case loaders do
      [] ->
        ast

      [loader] ->
        quote do
          case unquote(loader.ast) do
            {:ok, unquote(loader.data_var)} -> unquote(ast)
            other -> other
          end
        end

      loaders ->
        reverse_asts = Enum.reduce(loaders, [], &[&1.ast | &2])

        quote do
          case Dx.Defd.Result.collect_reverse(unquote(reverse_asts), {:ok, []}) do
            {:ok, unquote(Enum.map(loaders, & &1.data_var))} -> unquote(ast)
            other -> other
          end
        end
    end
  end

  defp cleanup({:__block__, meta, _lines} = block) do
    case cleanup_line(block) do
      [ast] -> ast
      lines -> {:__block__, meta, unwrap_lines(lines)}
    end
  end

  defp cleanup(ast) do
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

  ## Helpers

  @compile {:inline, with_state: 2}
  defp with_state(ast, state), do: {ast, state}

  ## Inspect

  defimpl Inspect do
    def inspect(loader, opts) do
      code = &Code.quoted_to_algebra(&1, syntax_colors: Map.get(opts, :syntax_colors, []))

      Inspect.Algebra.container_doc(
        "Loader{",
        [code.(loader.data_var), "->", code.(loader.clean_ast)],
        "}",
        opts,
        fn str, _ -> str end,
        separator: Inspect.Algebra.empty()
      )
    end
  end
end
