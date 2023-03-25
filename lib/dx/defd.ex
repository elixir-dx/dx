defmodule Dx.Defd do
  defmacro load(call, opts \\ []) do
    env = __CALLER__
    {name, args} = decompose_call!(:def, call, env)
    defd_name = defd_name(name)

    quote do
      eval = Dx.Evaluation.from_options(unquote(opts))

      Dx.load_all_data_reqs(eval, fn _eval ->
        unquote(defd_name)(unquote_splicing(args))
      end)
    end
  end

  defmacro defd(call, do: block) do
    define_defd(:def, call, block, __CALLER__)
  end

  defp define_defd(kind, call, block, env) do
    assert_no_guards!(kind, call, env)
    # Note name here is not necessarily an atom due to unquote(name) support
    {name, args} = decompose_call!(kind, call, env)
    arity = length(args)

    defaults =
      for {{:\\, meta, [_, default]}, i} <- Enum.with_index(args),
          do: {i, {meta, Macro.escape(default)}},
          into: []

    quote do
      unquote(__MODULE__).__define__(
        __MODULE__,
        unquote(kind),
        unquote(name),
        unquote(arity),
        %{unquote_splicing(defaults)}
      )

      unquote(kind)(unquote(call)) do
        unquote(block)
      end
    end
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

  defp assert_no_guards!(kind, {:when, _, _}, env) do
    compile_error!(env, "guards are not supported by #{kind}d")
  end

  defp assert_no_guards!(_kind, _call, _env), do: :ok

  # Internal attributes
  @defd_exports_key :__defd_exports__

  @doc false
  def __define__(module, kind, name, arity, defaults) do
    exports =
      if exports = Module.get_attribute(module, @defd_exports_key) do
        exports
      else
        Module.put_attribute(module, :before_compile, __MODULE__)
        %{}
      end

    current_export = %{
      kind: kind,
      defaults: defaults
    }

    exports = Map.put(exports, {name, arity}, current_export)

    Module.put_attribute(module, @defd_exports_key, exports)
    :ok
  end

  defp compile_error!(env, description) do
    raise CompileError, line: env.line, file: env.file, description: description
  end

  defp defd_name(name), do: :"__defd:#{name}__"

  @doc false
  defmacro __before_compile__(env) do
    defd_exports = Module.get_attribute(env.module, @defd_exports_key)
    Dx.Defd.Compiler.__compile__(env, defd_exports)
  end
end
