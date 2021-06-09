defmodule Infer.Parser do
  @moduledoc """
  Receives the module attributes created by the macros in `Infer.DSL`
  and converts them into normalized `aliases` and lists of `Infer.Rule` structs.
  """

  defmodule Token do
    @doc """
    Encapsulates all static args to be passed around between functions.
    """

    use TypedStruct

    typedstruct do
      field(:type, module())
      field(:aliases, %{atom() => any()}, default: %{})
      field(:opts, map(), default: %{})
    end

    def with_opts(token, opts), do: %{token | opts: Map.new(opts)}

    def set_aliases(token, new_aliases) do
      Map.update!(token, :aliases, fn aliases ->
        Enum.reduce(new_aliases, aliases, fn
          {key, nil}, aliases -> Map.delete(aliases, key)
          {key, val}, aliases -> Map.put(aliases, key, val)
        end)
      end)
    end
  end

  @option_keys [:when, :then]

  def normalize_aliases(aliases) do
    aliases
    |> List.flatten()
    |> Map.new(fn {key, val} -> {key, List.wrap(val)} end)
  end

  @doc """
  Entry point for this module
  """
  def parse(directives, token) do
    directives
    |> Enum.reduce({[], token}, fn
      {:infer_alias, aliases}, {rules, token} ->
        new_token = Token.set_aliases(token, aliases)
        {rules, new_token}

      directive, {rules, token} ->
        new_rules = directive_to_rules(directive, token)
        {Enum.reverse(new_rules) ++ rules, token}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  # def directive_to_rules({:infer_alias, opts}, token) do
  #   to_aliased_rules(%{key => true}, Token.with_opts(token, opts))
  # end

  def directive_to_rules({:infer, key, opts}, token) when is_atom(key) do
    to_aliased_rules(%{key => true}, Token.with_opts(token, opts))
  end

  def directive_to_rules({:infer, key}, token) when is_atom(key) do
    to_aliased_rules(%{key => true}, token)
  end

  def directive_to_rules({:infer, then, opts}, token) when is_list(then) do
    then
    |> Map.new(fn
      key when is_atom(key) -> {key, true}
      {key, val} -> {key, val}
    end)
    |> to_aliased_rules(Token.with_opts(token, opts))
  end

  def directive_to_rules({:infer, then, opts}, token) when is_map(then) do
    to_aliased_rules(then, Token.with_opts(token, opts))
  end

  def directive_to_rules({:infer, opts}, token) when is_list(opts) do
    {assigns, opts} = split_assigns(%{}, opts)
    to_aliased_rules(assigns, Token.with_opts(token, opts))
  end

  def directive_to_rules({:import, mod, opts}, _token) when is_list(opts) do
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

  defp to_aliased_rules(assigns, token) do
    Enum.flat_map(assigns, &to_rules(&1, token))
  end

  defp to_rules({key, val}, token) do
    Map.get(token.aliases, key, [key])
    |> Enum.map(&to_rule(&1, val, token))
  end

  defp to_rule(key, val, token) do
    attrs = Map.merge(token.opts, %{key: key, val: val, type: token.type})

    struct!(Infer.Rule, attrs)
    |> Map.update!(:when, &normalize_condition/1)
    |> Map.update!(:when, &replace_aliases(&1, token.aliases))
    |> Map.update!(:val, &replace_aliases(&1, token.aliases))
  end

  defp normalize_condition(atom) when is_atom(atom), do: %{atom => true}
  defp normalize_condition(condition), do: condition

  defp replace_aliases(%type{} = struct, aliases) do
    fields =
      struct
      |> Map.from_struct()
      |> replace_aliases(aliases)

    struct(type, fields)
  end

  defp replace_aliases(map, aliases) when is_map(map) do
    Map.new(map, fn {key, val} ->
      {replace_aliases(key, aliases), replace_aliases(val, aliases)}
    end)
  end

  defp replace_aliases(list, aliases) when is_list(list) do
    Enum.map(list, &replace_aliases(&1, aliases))
  end

  defp replace_aliases(key, aliases) when is_map_key(aliases, key) do
    Map.get(aliases, key)
  end

  defp replace_aliases(other, _aliases) do
    other
  end
end
