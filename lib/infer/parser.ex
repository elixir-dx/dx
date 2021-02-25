defmodule Infer.Parser do
  @option_keys [:when, :then, :desc]

  def normalize_aliases(aliases) do
    aliases
    |> List.flatten()
    |> Map.new(fn {key, val} -> {key, List.wrap(val)} end)
  end

  def directive_to_rules({:infer, key, opts}, type, aliases) when is_atom(key) do
    to_aliased_rules(%{key => true}, opts, type, aliases)
  end

  def directive_to_rules({:infer, key}, type, aliases) when is_atom(key) do
    to_aliased_rules(%{key => true}, [], type, aliases)
  end

  def directive_to_rules({:infer, then, opts}, type, aliases) when is_list(then) do
    then
    |> Map.new(fn
      key when is_atom(key) -> {key, true}
      {key, val} -> {key, val}
    end)
    |> to_aliased_rules(opts, type, aliases)
  end

  def directive_to_rules({:infer, then, opts}, type, aliases) when is_map(then) do
    to_aliased_rules(then, opts, type, aliases)
  end

  def directive_to_rules({:infer, opts}, type, aliases) when is_list(opts) do
    {assigns, opts} = split_assigns(%{}, opts)
    to_aliased_rules(assigns, opts, type, aliases)
  end

  def directive_to_rules({:import, mod, opts}, _type, _aliases) when is_list(opts) do
    rules = mod.infer_rules()

    case opts do
      [] -> rules
      [only: keys] -> Enum.filter(rules, &(&1.key in keys))
      [except: keys] -> Enum.reject(rules, &(&1.key in keys))
    end
  end

  defp split_assigns(assigns, []), do: {assigns, []}
  defp split_assigns(assigns, opts = [{key, _} | _]) when key in @option_keys, do: {assigns, opts}

  defp split_assigns(assigns, [key | opts]) when is_atom(key),
    do: assigns |> Map.put(key, true) |> split_assigns(opts)

  defp split_assigns(assigns, [{key, val} | opts]),
    do: assigns |> Map.put(key, val) |> split_assigns(opts)

  defp to_aliased_rules(assigns, opts, type, aliases) do
    Enum.flat_map(assigns, &to_rules(&1, opts, type, aliases))
  end

  defp to_rules({key, val}, opts, type, aliases) do
    Map.get(aliases, key, [key])
    |> Enum.map(&to_rule(&1, val, type, opts))
  end

  defp to_rule(key, val, type, opts) do
    struct!(Infer.Rule, [{:key, key}, {:val, val}, {:type, type} | opts])
    |> Map.update!(:when, &normalize_condition/1)
  end

  defp normalize_condition(atom) when is_atom(atom), do: %{atom => true}
  defp normalize_condition(condition), do: condition
end
