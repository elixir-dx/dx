defmodule Dx.Defd_ do
  @moduledoc """
  Used to make existing libraries compatible with `Dx.Defd`.

  ## Defining functions

  Define functions using `defd_/2`. The `_` stands for *basic* or *native*.
  `defd_` functions are not recompiled by the Dx compiler.
  They have to return either `{:ok, result}` or `{:not_loaded, data_reqs}`.
  See `Dx.Defd.Result` for more information and Enum-like functions to work with results.

  The input arguments can be a `Dx.Scope` struct or a `Dx.Defd.Fn` struct.
  If you don't want to handle these internal structs, you can tell the compiler
  to load/unwrap them by providing function information (see next section).

  ## Function information

  ```elixir
  defmodule MyExt do
    use Dx.Defd_

    @dx_ args: [:preload_scope, :fn], warn_not_ok: "Be careful!"
    defd_ map(enum, mapper) do
      # ...
    end
  end
  ```

  ### Options

  - `args` - list or map of argument indexes mapping to argument information
    - List format: `[:preload_scope, %{}, :fn]` - each element maps to an argument position
    - Map format with special keys (highest to lowest precedence):
      - Positive argument indexes (0..arity-1) counting from the first argument: `%{0 => :preload_scope}`
      - Negative argument indexes (-1..-arity) counting from the last argument: `%{-1 => :preload_scope}`
      - `:all` - sets defaults for all arguments (explicitly defined or not)

  Argument information options:
    - `:atom_to_scope` - whether to wrap atoms in `Dx.Scope.all/1`
    - `:preload_scope` - tells the compiler to load any scopes passed via this argument
    - `:fn` - tells the compiler to unwrap any Dx-specific function definitions
    - `{:fn, arity: 2, warn_not_ok: "Can't load data here"}` - pass more information about the function
    - `:final_args_fn` - like `fn` but assumes that no scopes can be passed to the function in this argument
    - `{:final_args_fn, arity: 2, warn_always: "Don't use this function"}` - pass more information about the function
    - `%{}` or `[]` - placeholder for an argument without any special information

  Additional options:
    - `warn_not_ok` - compiler warning to display when the function possibly loads data
    - `warn_always` - compiler warning to display when the function is used

  ### Examples

  ```elixir
  defmodule MyExt do
    use Dx.Defd_

    # Using list format - positional arguments
    @dx_ args: [:preload_scope, %{}, :final_args_fn]
    defd_ my_function(scope, value, callback) do
      # ...
    end

    # Using map format with positive and negative indexes
    @dx_ args: %{0 => :preload_scope, -1 => :fn}, warn_not_ok: "Be careful!"
    defd_ another_function(scope, value, callback) do
      # ...
    end

    # Using :all to set defaults for all arguments
    @dx_ args: %{all: :atom_to_scope, 0 => :preload_scope}
    defd_ process_all(first, second, third) do
      # first will be :preload_scope, all will have :atom_to_scope
    end
  end
  ```

  ## Compiler annotations & callbacks

  There are three ways to provide function information for the Dx compiler:

  1. Using `@dx_` module attributes before function definitions:

  ```elixir
  defmodule MyExt do
    use Dx.Defd_

    @dx_ args: [:preload_scope, %{}, :final_args_fn]
    defd_ my_function(scope, value, callback) do
      # ...
    end

    @dx_ args: %{0 => :preload_scope}, warn_not_ok: "Be careful!"
    defd_ another_function(scope, value) do
      # ...
    end
  end
  ```

  `args` options will also be derived for functions with omitted default arguments.

  2. Using the `@moduledx_` module attribute for module-wide defaults (can only be set once per module):

  ```elixir
  defmodule MyExt do
    use Dx.Defd_

    @moduledx_ args: %{all: :atom_to_scope},
               warn_always: "This module is deprecated"
  end
  ```

  3. Implementing the `__dx_fun_info/2` callback:

  ```elixir
  defmodule MyExt do
    use Dx.Defd_

    @impl true
    def __dx_fun_info(fun_name, arity) do
      %FunInfo{args: [:preload_scope, %{}, :final_args_fn]}
    end
  end
  ```

  All three approaches can be combined. The precedence order (highest to lowest) is:

  1. `@dx_` function-specific annotations
    - merged into `@moduledx_` defaults for that function
  2. `__dx_fun_info/2` callback implementations
    - always overrides `@moduledx_` defaults
  3. `@moduledx_` module-wide defaults

  ```elixir
  defmodule MyExt do
    use Dx.Defd_

    # Module-wide defaults (lowest precedence)
    # Must be set once with all defaults
    @moduledx_ args: %{all: :preload_scope},
               warn_always: "Module under development"

    # Function pattern in __dx_fun_info (middle precedence)
    def __dx_fun_info(:special_case, 2) do
      %FunInfo{args: [:preload_scope, :final_args_fn]}
    end

    # Function-specific override (highest precedence)
    @dx_ args: [:preload_scope, :fn]
    defd_ process_data(scope, callback) do
      # This function's settings override both __dx_fun_info and @moduledx_
    end

    # Uses __dx_fun_info(:special_case, 2) settings
    defd_ special_case(a, b) do
      # ...
    end

    # Falls back to default @moduledx_ settings
    defd_ other_function(x) do
      # ...
    end
  end
  ```
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Dx.Defd_

      alias Dx.Defd_.ArgInfo
      alias Dx.Defd_.FunInfo

      import Dx.Defd_

      unquote(__MODULE__).__init__(__MODULE__)
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
  def __init__(module) do
    Module.put_attribute(module, @defd__exports_key, %{})
    Module.put_attribute(module, :before_compile, __MODULE__)
  end

  @doc false
  def __define__(%Macro.Env{module: module}, _kind, _name, _arity, _defaults, nil) do
    if is_nil(Module.get_attribute(module, @defd__exports_key)) do
      __init__(module)
    end

    :ok
  end

  def __define__(%Macro.Env{module: module} = env, kind, name, arity, defaults, opts) do
    fun_info =
      try do
        Dx.Defd_.FunInfo.new!(
          Module.get_attribute(module, :moduledx_, []),
          %{arity: arity},
          opts || [],
          %{module: module, fun_name: name}
        )
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

    exports =
      if exports = Module.get_attribute(module, @defd__exports_key) do
        exports
      else
        Module.put_attribute(module, :before_compile, __MODULE__)
        %{}
      end

    exports = Map.put_new(exports, {name, arity}, current_export)

    Module.put_attribute(module, @defd__exports_key, exports)
    :ok
  end

  defp compile_error!(env, description) do
    raise CompileError, line: env.line, file: env.file, description: description
  end

  @doc false
  defmacro __before_compile__(env) do
    defd__exports = Module.get_attribute(env.module, @defd__exports_key, %{})
    moduledx_ = Module.get_attribute(env.module, :moduledx_, [])

    Dx.Defd_.Compiler.__compile__(env, moduledx_, defd__exports)
  end
end
