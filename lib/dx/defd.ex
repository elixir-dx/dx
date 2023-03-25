defmodule Dx.Defd do
  defmacro load(call, opts \\ []) do
    IO.inspect(call, label: :defd)
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
    defd_name = defd_name(name)

    quote do
      unquote(kind)(unquote(name)(unquote_splicing(args))) do
        warn(unquote(env), """
        Use Dx.load as entrypoint.
        """)

        Dx.Defd.load(unquote(name)(unquote_splicing(args)))
      end

      unquote(kind)(unquote(defd_name)(unquote_splicing(args))) do
        {:ok, unquote(block)}
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

  defp compile_error!(env, description) do
    raise CompileError, line: env.line, file: env.file, description: description
  end

  defmacro warn(env, message) do
    IO.warn(message, env)
    :ok
  end

  defp defd_name(name), do: :"__defd:#{name}__"
end
