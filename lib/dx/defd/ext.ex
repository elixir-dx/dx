defmodule Dx.Defd.Ext do
  @moduledoc false

  alias Dx.Defd.Util

  defmacro defscope(call) do
    define_scope(:def, call, __CALLER__)
  end

  defmacro defscope(call, do: block) do
    define_scope(:def, call, block, __CALLER__)
  end

  defmacro defd_(call) do
    define_defd_(:def, call, __CALLER__)
  end

  defmacro defd_(call, do: block) do
    define_defd_(:def, call, block, __CALLER__)
  end

  defp define_scope(kind, call, env) do
    {name, args} = replace_function_name!(kind, call, env, &Util.scope_name/1)

    quote do
      unquote(kind)(unquote(name)(unquote_splicing(args)))
    end
  end

  defp define_scope(kind, call, block, env) do
    {name, args} = replace_function_name!(kind, call, env, &Util.scope_name/1)

    quote do
      unquote(kind)(unquote(name)(unquote_splicing(args))) do
        unquote(block)
      end
    end
  end

  defp define_defd_(kind, call, env) do
    # Note name here is not necessarily an atom due to unquote(name) support
    {name, args} = decompose_call!(kind, call, env)
    arity = length(args)

    defaults = defaults_for(args)

    quote do
      unquote(__MODULE__).__define__(
        __MODULE__,
        unquote(kind),
        unquote(name),
        unquote(arity),
        %{unquote_splicing(defaults)},
        Module.delete_attribute(__MODULE__, :dx)
      )

      unquote(kind)(unquote(call))
    end
  end

  defp define_defd_(kind, call, block, env) do
    # Note name here is not necessarily an atom due to unquote(name) support
    {name, args} = decompose_call!(kind, call, env)
    arity = length(args)

    defaults = defaults_for(args)

    quote do
      unquote(__MODULE__).__define__(
        __MODULE__,
        unquote(kind),
        unquote(name),
        unquote(arity),
        %{unquote_splicing(defaults)},
        Module.delete_attribute(__MODULE__, :dx)
      )

      unquote(kind)(unquote(call)) do
        unquote(block)
      end
    end
  end

  defp defaults_for(args) do
    for {{:\\, meta, [_var, default]}, i} <- Enum.with_index(args),
        do: {i, {meta, Macro.escape(default)}},
        into: []
  end

  defp decompose_call!(kind, {:when, _, [call, _guards]}, env),
    do: decompose_call!(kind, call, env)

  defp decompose_call!(_kind, {{:unquote, _, [name]}, _, args}, _env) do
    {name, args}
  end

  defp decompose_call!(kind, call, env) do
    case Macro.decompose_call(call) do
      {name, args} ->
        {name, args}

      :error ->
        compile_error!(
          env,
          "first argument of #{kind}d must be a call, got: #{Macro.to_string(call)}"
        )
    end
  end

  defp replace_function_name!(kind, {:when, meta, [call, guards]}, env, fun) do
    {:when, meta, [replace_function_name!(kind, call, env, fun), guards]}
  end

  defp replace_function_name!(_kind, {{:unquote, _, [name]}, _, args}, _env, fun) do
    {fun.(name), args}
  end

  defp replace_function_name!(kind, call, env, fun) do
    case Macro.decompose_call(call) do
      {name, args} ->
        {fun.(name), args}

      :error ->
        compile_error!(
          env,
          "first argument of #{kind}d must be a call, got: #{Macro.to_string(call)}"
        )
    end
  end

  # Internal attributes
  @defd_exports_key :__defd_exports__
  @defd__exports_key :__defd__exports__
  @scope_exports_key :__defd_scope_exports__

  @doc false
  def __define__(module, kind, name, arity, defaults, opts) do
    exports =
      if exports = Module.get_attribute(module, @defd__exports_key) do
        exports
      else
        Module.put_attribute(module, :before_compile, __MODULE__)
        %{}
      end

    current_export = %{
      kind: kind,
      defaults: defaults,
      opts: opts || []
    }

    exports = Map.put_new(exports, {name, arity}, current_export)

    Module.put_attribute(module, @defd__exports_key, exports)
    :ok
  end

  defp compile_error!(env, description) do
    raise CompileError, line: env.line, file: env.file, description: description
  end

  @doc false
  defmacro __before_compile__(env) do
    defd_exports = Module.get_attribute(env.module, @defd_exports_key)
    defd__exports = Module.get_attribute(env.module, @defd__exports_key)
    scope_exports = Module.get_attribute(env.module, @scope_exports_key)

    quote do
      def __dx_defds__(), do: unquote(defd_exports ++ defd__exports)
      def __dx_scopes__(), do: unquote(scope_exports)
    end
  end
end
