defmodule Dx.Defd.Case do
  alias Dx.Defd.Compiler

  def normalize({:case, meta, [subject, [do: clauses]]}, state) do
    data_req = data_req_from_clauses(clauses, %{})
    quoted_data_req = Macro.escape(data_req)

    {clauses, state} = normalize_clauses(clauses, state)

    subject_var = Macro.unique_var(:subject, __MODULE__)
    ast = {:case, meta, [subject_var, [do: clauses]]}

    ast =
      quote do
        case Dx.Defd.Util.fetch(
               unquote(subject),
               unquote(quoted_data_req),
               unquote(state.eval_var)
             ) do
          {:ok, unquote(subject_var)} -> unquote(ast)
          other -> other
        end
      end

    {ast, state}
  end

  def normalize({:case, meta, _args}, state) do
    Compiler.compile_error!(meta, state, """
    Invalid case syntax. Add a do .. end block like the following:

    case ... do
      pattern -> result
      ...
    end
    """)
  end

  def normalize_clauses(clauses, state) do
    Enum.map_reduce(clauses, state, &normalize_clause/2)
  end

  def normalize_clause({:->, meta, [[pattern], ast]}, state) do
    {ast, state} = Compiler.normalize(ast, state)
    ast = {:->, meta, [[pattern], ast]}

    {ast, state}
  end

  defp data_req_from_clauses([], acc) do
    acc
  end

  defp data_req_from_clauses([{:->, _meta, [[pattern], _result]} | tail], acc) do
    data_req = quoted_data_req(pattern)
    acc = Dx.Util.deep_merge(acc, data_req)
    data_req_from_clauses(tail, acc)
  end

  defp quoted_data_req({elem_0, elem_1}) do
    %{{:__tuple__, 2} => %{0 => quoted_data_req(elem_0), 1 => quoted_data_req(elem_1)}}
  end

  defp quoted_data_req({:{}, _meta, tuple_elems}) do
    inner_reqs =
      tuple_elems
      |> Enum.with_index()
      |> Map.new(fn {elem, index} -> {index, quoted_data_req(elem)} end)

    %{{:__tuple__, length(tuple_elems)} => inner_reqs}
  end

  defp quoted_data_req(list) when is_list(list) do
    inner_reqs =
      list
      |> Enum.with_index()
      |> Map.new(fn {elem, index} -> {index, quoted_data_req(elem)} end)

    %{:__list__ => inner_reqs}
  end

  defp quoted_data_req({:%, _meta, [_type, map]}) do
    quoted_data_req(map)
  end

  defp quoted_data_req({:%{}, _meta, pairs}) do
    Map.new(pairs, fn
      {k, v} when is_atom(k) -> {k, quoted_data_req(v)}
      {k, v} -> {quoted_data_req(k), quoted_data_req(v)}
    end)
  end

  defp quoted_data_req(_other) do
    %{}
  end
end
