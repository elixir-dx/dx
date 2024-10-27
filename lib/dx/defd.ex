defmodule Dx.Defd do
  @external_resource Path.expand("./README.md")
  @moduledoc File.read!(Path.expand("./README.md"))
             |> String.split("<!-- MODULEDOC -->")
             |> Enum.drop(1)
             |> Enum.take_every(2)
             |> Enum.join()

  alias Dx.Defd.Ast
  alias Dx.Defd.Util
  alias Dx.Evaluation, as: Eval

  @eval_var Macro.var(:eval, Dx.Defd.Compiler)

  @doc """
  Like `load!/2` but returns `{:ok, result}` on success, `{:error, error}` on failure.

  See `load!/2` for a raising alternative, and `get!/2` and `get/2` for non-loading alternatives.
  """
  defmacro load(call, opts \\ []) do
    defd_call = call_to_defd(call, __ENV__)

    quote do
      Eval.load_all_data_reqs(unquote(opts), fn unquote(@eval_var) ->
        unquote(defd_call)
      end)
    end
    |> mark_use(call)
  end

  @doc """
  Wrap a `defd` function call to run it repeatedly, loading all required data.
  Raises an error if unsuccessful.

  See `load/2`, `get!/2` and `get/2` for non-raising and/or non-loading alternatives.

  ## Example

      defmodule MyApp.Core.Authorization do
        import Dx.Defd

        defd visible_lists(user) do
          if user.role.name == "Admin" do
            Enum.filter(Schema.List, &(&1.title == "Main list"))
          else
            user.lists
          end
        end
      end

      # Will raise if data loading fails
      Dx.Defd.load!(MyApp.Core.Authorization.visible_lists(user))
  """
  defmacro load!(call, opts \\ []) do
    defd_call = call_to_defd(call, __ENV__)

    quote do
      Eval.load_all_data_reqs!(unquote(opts), fn unquote(@eval_var) ->
        unquote(defd_call)
      end)
    end
    |> mark_use(call)
  end

  @doc """
  Like `load!/2` but returns a result tuple and evaluates without loading any data.

  Returns either
    - `{:ok, result}` on success
    - `{:error, error}` on failure
    - `{:not_loaded, data_reqs}` if required data is missing

  See `get!/2` for a raising alternative, and `load!/2` and `load/2` for loading alternatives.
  """
  defmacro get(call, opts \\ []) do
    defd_call = call_to_defd(call, __ENV__)

    quote do
      unquote(@eval_var) = Eval.from_options(unquote(opts))

      unquote(defd_call)
    end
    |> mark_use(call)
  end

  @doc """
  Like `load!/2` but evaluates without loading any data.

  See `get/2` for a non-raising alternative, and `load!/2` and `load/2` for loading alternatives.
  """
  defmacro get!(call, opts \\ []) do
    quote do
      Dx.Defd.get(unquote(call), unquote(opts))
      |> Dx.Result.unwrap!()
    end
    |> mark_use(call)
  end

  defp call_to_defd({:|>, _meta, _pipeline} = ast, env) do
    ast
    |> Macro.expand_once(env)
    |> call_to_defd(env)
  end

  defp call_to_defd({{:., meta, [module, name]}, meta2, args}, _env) do
    defd_name = Util.final_args_name(name)
    args = args ++ [@eval_var]

    {{:., meta, [module, defd_name]}, meta2, args}
  end

  defp call_to_defd({name, meta, args}, _env) do
    defd_name = Util.final_args_name(name)
    args = args ++ [@eval_var]

    {defd_name, meta, args}
  end

  defp mark_use(ast, call) do
    case call_to_use(call, __ENV__) do
      {name, arity} ->
        Ast.block([
          Ast.local_fun_ref(name, arity),
          ast
        ])

      _ ->
        ast
    end
  end

  defp call_to_use({:|>, _meta, _pipeline} = ast, env) do
    ast
    |> Macro.expand_once(env)
    |> call_to_use(env)
  end

  defp call_to_use(call, _env) do
    case Macro.decompose_call(call) do
      {name, args} -> {name, length(args)}
      _ -> nil
    end
  end

  @doc false
  defmacro defd(call) do
    define_defd(:def, call, __CALLER__)
  end

  @doc """
  Defines a function that automatically loads required data.

  `defd` functions are similar to regular Elixir functions defined with `def`,
  but they allow you to write code as if all data is already loaded.
  Dx will automatically handle loading the necessary data from the database
  when the function is called.

  ## Usage

  ```elixir
  defmodule MyApp.Core.Authorization do
    import Dx.Defd

    defd visible_lists(user) do
      if admin?(user) do
        Enum.filter(Schema.List, &(&1.title == "Main list"))
      else
        user.lists
      end
    end

    defd admin?(user) do
      user.role.name == "Admin"
    end
  end
  ```

  This can be called using

  ```elixir
  Dx.Defd.load!(MyApp.Core.Authorization.visible_lists(user))
  ```

  ## Important notes

  - `defd` functions should be pure and not have side effects.
  - They should not rely on external state or perform I/O operations.
  - Calls to non-`defd` functions should be wrapped in `non_dx/1`.
  - To call a `defd` function from regular Elixir code, wrap it in `Dx.Defd.load!/1`.

  ## Options

  Additional options can be passed via a `@dx` attribute right before the `defd` definition:

  ```elixir
  @dx def: :original
  defd visible_lists(user) do
    # ...
  end
  ```

  Available options:

  - `def:` - Determines what the generated non-defd function should do.
    - `:warn` (default) - Call the `defd` function wrapped in `Dx.Defd.load!/1` and emit a warning
      asking to make the wrapping explicit.
    - `:no_warn` - Call the `defd` function wrapped in `Dx.Defd.load!/1` without emitting a warning.
    - `:original` - Keep the original function definition. This means, the original function can still
      be called directly without being changed by Dx. The `defd` version *must* be called from other
      `defd` functions or by wrapping the call in `Dx.Defd.load!/1`. This can be useful when migrating
      existing code to Dx.
  - `debug:` - Takes one or multiple flags for printing generated code to the console. These *can* get
    *very* verbose, because Dx generates code for many combinations of cases. All flags have a `_raw`
    variant that prints the code without syntax highlighting.
    - `:original` - Prints the original function definition as passed to defd. All macros are already
      expanded at this point.
    - `:def` - Prints the `def` version, which is the generated non-defd function. See the `def:` option.
    - `:defd` - Prints the `defd` function definition.
    - `:final_args` - Prints the `final_args` version, which is similar to the `defd` version but
      can be slightly shorter for some internal optimizations. This is also the version used
      as the entrypoint when calling `Dx.Defd.load!/1`.
    - `:scope` - Prints the `scope` version, which is used to translate the function to SQL.
      It returns AST-like data structures with embedded `defd` code fallbacks.
    - `:all` - Enables all the flags.

  """
  defmacro defd(call, do: block) do
    define_defd(:def, call, block, __CALLER__)
  end

  @doc false
  defmacro defdp(call) do
    define_defd(:defp, call, __CALLER__)
  end

  @doc "Private version of `defd/2`."
  defmacro defdp(call, do: block) do
    define_defd(:defp, call, block, __CALLER__)
  end

  @doc """
  Used to wrap calls to non-Dx defined functions within a `defd` function.

  When writing `defd` functions, any calls to regular Elixir functions (non-`defd` functions)
  should be wrapped with `non_dx/1`. This makes the external calls explicit and suppresses
  Dx compiler warnings.

  ## Example

      defmodule MyApp.Core.Stats do
        import Dx.Defd

        def calculate_percentage(value, total) do
          (value / total) * 100
        end

        defd user_completion_rate(user) do
          completed = length(user.completed_tasks)
          total = length(user.all_tasks)

          # Wrap the regular def function call with non_dx
          non_dx(calculate_percentage(completed, total))
        end
      end
  """
  def non_dx(code) do
    code
  end

  defp define_defd(kind, call, env) do
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

  defp define_defd(kind, call, block, env) do
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

  # Internal attributes
  @defd_exports_key :__defd_exports__

  @doc false
  def __define__(module, kind, name, arity, defaults, opts) do
    exports =
      if exports = Module.get_attribute(module, @defd_exports_key) do
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

    Module.put_attribute(module, @defd_exports_key, exports)
    :ok
  end

  defp compile_error!(env, description) do
    raise CompileError, line: env.line, file: env.file, description: description
  end

  @doc false
  defmacro __before_compile__(env) do
    defd_exports = Module.get_attribute(env.module, @defd_exports_key)
    Dx.Defd.Compiler.__compile__(env, defd_exports, @eval_var)
  end
end
