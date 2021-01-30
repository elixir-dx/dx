defmodule Infer.Engine do
  @option_keys [:when, :then, :desc]

  def directive_to_rules({key, opts}) when is_atom(key) do
    to_rules(%{key => true}, opts)
  end

  def directive_to_rules({then, opts}) do
    to_rules(then, opts)
  end

  def directive_to_rules(opts) when is_list(opts) do
    {assigns, opts} = split_assigns(%{}, opts |> IO.inspect())
    to_rules(assigns, opts)
  end

  defp split_assigns(assigns, []), do: {assigns, []}
  defp split_assigns(assigns, opts = [{key, _} | _]) when key in @option_keys, do: {assigns, opts}

  defp split_assigns(assigns, [key | opts]) when is_atom(key),
    do: assigns |> Map.put(key, true) |> split_assigns(opts)

  defp split_assigns(assigns, [{key, val} | opts]),
    do: assigns |> Map.put(key, val) |> split_assigns(opts)

  defp to_rules(assigns, opts) do
    Enum.map(assigns, &to_rule(&1, opts))
  end

  defp to_rule({key, val}, opts) do
    struct!(Infer.Rule, [{:key, key}, {:val, val} | opts])
  end
end
