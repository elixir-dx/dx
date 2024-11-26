defmodule Dx.Defd_ do
  @moduledoc """
  Used to make existing libraries compatible with `Dx.Defd`.

  ## Usage

  ```elixir
  defmodule MyExt do
    use Dx.Defd_

    @impl true
    def __dx_fun_info(fun_name, arity) do
      %FunInfo{args: [:preload_scope, %{}, :final_args_fn]}
    end
  end
  ```

  ## Options

  Return a map with the following keys:

  - `args` - list or map of argument indexes mapping to argument information
    - `:atom_to_scope` - whether to wrap atoms in `Dx.Scope.all/1`
    - `:preload_scope` - tells the compiler to load any scopes passed via this argument
    - `:fn` - tells the compiler to unwrap any Dx-specific function definitions
    - `{:fn, arity: 2, warn_not_ok: "Can't load data here"}` - pass more information about the function
    - `:final_args_fn` - like `fn` but assumes that no scopes can be passed to the function in this argument
    - `{:final_args_fn, arity: 2, warn_always: "Don't use this function"}` - pass more information about the function
    - `%{}` - placeholder for an argument without any special information
  - `warn_not_ok` - compiler warning to display when the function possibly loads data
  - `warn_always` - compiler warning to display when the function is used
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Dx.Defd_

      alias Dx.Defd_.ArgInfo
      alias Dx.Defd_.FunInfo

      import Dx.Defd_
    end
  end

  @doc """
  This callback is used to provide information about a function to `Dx.Defd`.
  """
  @callback __dx_fun_info(atom(), non_neg_integer()) :: __MODULE__.FunInfo.input()

  @optional_callbacks __dx_fun_info: 2

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
    case replace_function_name!(kind, call, env, &Util.scope_name/1) do
      {name, args} ->
        quote do
          unquote(kind)(unquote(name)(unquote_splicing(args))) do
            unquote(block)
          end
        end

      {:when, _meta, [{name, args}, guards]} ->
        quote do
          unquote(kind)(
            unquote(name)(unquote_splicing(args))
            when unquote_splicing(guards)
          ) do
            unquote(block)
          end
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
        unquote(Macro.escape(env)),
        unquote(kind),
        unquote(name),
        unquote(arity),
        %{unquote_splicing(defaults)},
        Module.delete_attribute(__MODULE__, :dx_)
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
        unquote(Macro.escape(env)),
        unquote(kind),
        unquote(name),
        unquote(arity),
        %{unquote_splicing(defaults)},
        Module.delete_attribute(__MODULE__, :dx_)
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

  defp replace_function_name!(kind, {:when, meta, [call | guards]}, env, fun) do
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
  @defd__exports_key :__defd__exports__

  @doc false
  def __define__(_env, _kind, _name, _arity, _defaults, nil) do
    :ok
  end

  def __define__(%Macro.Env{module: module} = env, kind, name, arity, defaults, opts) do
    exports =
      if exports = Module.get_attribute(module, @defd__exports_key) do
        exports
      else
        Module.put_attribute(module, :before_compile, __MODULE__)
        %{}
      end

    fun_info =
      try do
        Dx.Defd_.FunInfo.new!(opts || [], %{module: module, fun_name: name, arity: arity})
      rescue
        e ->
          compile_error!(
            env,
            """
            #{Exception.message(e)}

            in annotation

            @dx #{opts |> List.wrap() |> inspect() |> String.replace_prefix("[", "") |> String.replace_suffix("]", "")}
            """
          )
      end

    current_export = %{
      kind: kind,
      defaults: defaults,
      fun_info: fun_info
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
    defd__exports = Module.get_attribute(env.module, @defd__exports_key)

    Dx.Defd_.Compiler.__compile__(env, defd__exports)
  end
end
