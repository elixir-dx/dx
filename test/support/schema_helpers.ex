defmodule Test.Support.SchemaHelpers do
  def expand_mapping(mapping, type, opts \\ []) do
    eval = opts |> Keyword.put_new(:root_type, type) |> Dx.Evaluation.from_options()
    Dx.Schema.expand_mapping(mapping, type, eval)
  end

  def expand_result(result, type, opts \\ []) do
    eval = opts |> Keyword.put_new(:root_type, type) |> Dx.Evaluation.from_options()
    Dx.Schema.expand_result(result, type, eval)
  end

  def expand_condition(condition, type, opts \\ []) do
    eval = Dx.Evaluation.from_options(opts)
    {expanded, _binds} = Dx.Schema.expand_condition(condition, type, eval)
    expanded
  end
end
