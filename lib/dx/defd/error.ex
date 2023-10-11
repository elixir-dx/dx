defmodule Dx.Defd.Error do
  @strip_modules [Dx.Evaluation]

  @doc """
  Rewrites the stacktrace making defd occurrences look like their non-defd counterparts.

  ## Examples

     iex> rewrite_stacktrace([
     ...>   {Dx.Defd.EnumTest.InvalidFieldInExtFnTest, :"-__defd:run__/2-fun-0-", 1,
     ...>   [file: 'test/dx/defd/enum_test.exs', line: 163]}
     ...> ])
     [{Dx.Defd.EnumTest.InvalidFieldInExtFnTest, :"-run/1-fun-0-", 1, [file: 'test/dx/defd/enum_test.exs', line: 163]}]

     iex> rewrite_stacktrace([
     ...>   {Enum, :"-map/2-lists^map/1-0-", 2, [file: 'lib/enum.ex', line: 1658]}
     ...> ])
     [{Enum, :"-map/2-lists^map/1-0-", 2, [file: 'lib/enum.ex', line: 1658]}]

     iex> rewrite_stacktrace([
     ...>   {Dx.Defd.EnumTest.InvalidFieldInExtFnTest, :"__defd:run__", 2,
     ...>   [file: 'test/dx/defd/enum_test.exs', line: 162]}
     ...> ])
     [{Dx.Defd.EnumTest.InvalidFieldInExtFnTest, :run, 1, [file: 'test/dx/defd/enum_test.exs', line: 162]}]

     iex> rewrite_stacktrace([
     ...>   {Dx.Defd.EnumTest, :"-test nested Invalid field in external fn body/1-fun-2-", 1,
     ...>   [file: 'test/dx/defd/enum_test.exs', line: 191]}
     ...> ])
     [{Dx.Defd.EnumTest, :"-test nested Invalid field in external fn body/1-fun-2-", 1, [file: 'test/dx/defd/enum_test.exs', line: 191]}]
  """
  def rewrite_stacktrace(stacktrace) do
    stacktrace
    |> Enum.flat_map(fn
      {module, _, _, _} when module in @strip_modules ->
        []

      {mod, fun_name, arity, meta} ->
        {fun_name, arity} = replace_defd_refs(fun_name, arity)

        [{mod, fun_name, arity, meta}]

      entry ->
        [entry]
    end)
  end

  def filter_and_reraise(exception, stacktrace) do
    exception = replace_defd_refs(exception)
    stacktrace = rewrite_stacktrace(stacktrace)
    reraise exception, stacktrace
  end

  defp replace_defd_refs(%type{} = struct) do
    struct |> Map.from_struct() |> replace_defd_refs() |> then(&struct(type, &1))
  end

  defp replace_defd_refs(%{function: fun_name, arity: arity} = map) do
    {defd_name, arity} = replace_defd_refs(fun_name, arity)

    %{map | function: defd_name, arity: arity}
    |> replace_defd_refs_in_map()
  end

  defp replace_defd_refs(map) when is_map(map) do
    replace_defd_refs_in_map(map)
  end

  defp replace_defd_refs(other) do
    other
  end

  defp replace_defd_refs(atom, arity) when is_atom(atom) do
    case Atom.to_string(atom) do
      "__defd:" <> _ = str ->
        atom =
          replace_fun_names_and_arities(str)
          |> String.to_existing_atom()

        {atom, remove_last_arg(arity)}

      "-__defd:" <> _ = str ->
        atom =
          replace_fun_names_and_arities(str)
          |> String.to_atom()

        {atom, arity}

      _ ->
        {atom, arity}
    end
  end

  @regex ~r/__defd:([^\/]+)__(\/(\d+))?/
  defp replace_fun_names_and_arities(str) do
    Regex.replace(@regex, str, fn
      _full, fun_name, _optional, "" -> fun_name
      _full, fun_name, _optional, arity -> "#{fun_name}/#{String.to_integer(arity) - 1}"
    end)
  end

  defp remove_last_arg(arity) when is_integer(arity) do
    arity - 1
  end

  defp remove_last_arg(args) when is_list(args) do
    args |> Enum.reverse() |> List.delete_at(0) |> Enum.reverse()
  end

  defp replace_defd_refs_in_map(map) do
    Map.new(map, fn {k, v} -> {k, replace_defd_refs(v)} end)
  end
end
