defmodule Dx.Defd.Fn do
  @moduledoc """
  Internal wrapper for a function.

  This includes multiple compiled versions of the function, plus some meta information on whether
  the function can ever load any data (i.e. return `{:not_loaded, ...}` instead of `{:ok, ...}`).

  The `final_args` versions assume that arguments are already finalized, i.e. hold no `Dx.Scope` or
  `Dx.Defd.Fn` structs.
  """

  @typedoc """
  A wrapper struct for a function with multiple compiled versions and metadata.

  Fields:
  - `:ok?` - Whether the function can be guaranteed to return `{:ok, result}`
  - `:final_args_ok?` - Whether the function can be guaranteed to return `{:ok, result}` when given final arguments
  - `:fun` - defd-compatible function that may return `{:not_loaded, ...}` or `{:ok, ...}`
  - `:ok_fun` - Version of function guaranteed to return `{:ok, ...}` (can be nil)
  - `:final_args_fun` - Version of function that assumes final arguments
  - `:final_args_ok_fun` - Version of function that assumes final arguments and returns `{:ok, ...}` (can be nil)
  - `:scope` - scope version of the function. See `Dx.Scope`.
  """
  @type t :: %__MODULE__{
          ok?: boolean(),
          final_args_ok?: boolean(),
          fun: function(),
          ok_fun: function() | nil,
          final_args_fun: function(),
          final_args_ok_fun: function() | nil,
          scope: function()
        }

  defstruct [:ok?, :final_args_ok?, :fun, :ok_fun, :final_args_fun, :final_args_ok_fun, :scope]

  @doc """
  Extracts the defd-compatible function from a `Dx.Defd.Fn` struct if given one, otherwise returns the input unchanged.
  """
  def maybe_unwrap(%__MODULE__{fun: fun}), do: fun
  def maybe_unwrap(other), do: other

  @doc """
  Extracts the `ok_fun` from a `Dx.Defd.Fn` struct if given one, otherwise returns the input unchanged.
  The `ok_fun` is guaranteed to return `{:ok, result}`.
  """
  def maybe_unwrap_ok(%__MODULE__{ok_fun: fun}), do: fun
  def maybe_unwrap_ok(other), do: other

  @doc """
  Extracts the `final_args_ok_fun` from a `Dx.Defd.Fn` struct if given one, otherwise returns the input unchanged.
  The `final_args_ok_fun` assumes final arguments and is guaranteed to return `{:ok, result}`.
  """
  def maybe_unwrap_final_args_ok(%__MODULE__{final_args_ok_fun: fun}), do: fun
  def maybe_unwrap_final_args_ok(other), do: other

  @doc """
  Convert a function or `Dx.Defd.Fn` struct to a function returning a `Dx.Defd.Result`.
  """
  def to_defd_fun(%__MODULE__{fun: fun}), do: fun
  def to_defd_fun(fun) when is_function(fun), do: wrap_defd_fun(fun)
  def to_defd_fun(other), do: other

  wrap_defd_args = Macro.generate_arguments(12, __MODULE__)

  for arity <- 0..12, args = Enum.take(wrap_defd_args, arity) do
    defp wrap_defd_fun(fun) when is_function(fun, unquote(arity)) do
      fn unquote_splicing(args) ->
        {:ok, fun.(unquote_splicing(args))}
      end
    end
  end

  ## Compiler

  alias Dx.Defd.Ast
  alias Dx.Defd.Ast.State
  alias Dx.Defd.Case.Clauses

  @doc false
  def normalize(
        {:fn, meta, [{:->, _meta, [args_and_guards, _body]} | _] = clauses} = orig_ast,
        state
      ) do
    args = args_without_guards(args_and_guards)
    arity = length(args)
    generated_args = Macro.generate_unique_arguments(arity, __MODULE__)

    external_scope_args = generated_args
    internal_scope_args = generated_args
    scope_args_map = Enum.zip(external_scope_args, internal_scope_args)
    scope_args = generated_args

    {scope_ast, scope_state} =
      State.pass_in(
        state,
        [warn_non_dx?: false, scope_args: scope_args_map],
        fn state ->
          Ast.with_args_no_loaders!(args, state, fn state ->
            Dx.Scope.Compiler.normalize(orig_ast, state)
          end)
        end
      )

    case_clauses = Dx.Defd.Case.Clauses.from_fn_clauses(clauses)

    line = meta[:line] || state.line
    case_subject = Ast.wrap_args(generated_args)
    case_ast = {:case, [line: line], [case_subject, [do: case_clauses]]}

    {final_args_ast, final_args_state} =
      State.pass_in(
        state,
        [warn_non_dx?: false, finalized_vars: &Ast.collect_vars(generated_args, &1)],
        fn state ->
          Ast.with_root_args(generated_args, state, fn state ->
            Dx.Defd.Case.normalize(case_ast, state)
          end)
        end
      )

    final_args_ok? = match?({:ok, _}, final_args_ast)

    final_args_fun =
      case final_args_ast do
        {:ok, {:case, _meta, [^case_subject, [do: case_clauses]]}} ->
          {:fn, meta, Clauses.to_fn_clauses(case_clauses, args, &{:ok, &1})}

        {:case, _meta, [^case_subject, [do: case_clauses]]} ->
          {:fn, meta, Clauses.to_fn_clauses(case_clauses, args)}

        _other ->
          {:fn, meta, [{:->, meta, [generated_args, final_args_ast]}]}
      end

    {body, state} =
      Ast.with_root_args(generated_args, state, fn state ->
        Dx.Defd.Case.normalize(case_ast, state)
      end)

    ok? = match?({:ok, _}, body)

    fun =
      case body do
        {:ok, {:case, _meta, [^case_subject, [do: case_clauses]]}} ->
          {:fn, meta, Clauses.to_fn_clauses(case_clauses, args, &{:ok, &1})}

        {:case, _meta, [^case_subject, [do: case_clauses]]} ->
          {:fn, meta, Clauses.to_fn_clauses(case_clauses, args)}

        _other ->
          {:fn, meta, [{:->, meta, [generated_args, body]}]}
      end

    var_index = Enum.max([scope_state.var_index, final_args_state.var_index, state.var_index])
    new_state = %{state | var_index: var_index}

    line = meta[:line] || state.line

    {:ok,
     {:%, [line: line],
      [
        {:__aliases__, [line: line, alias: false], [:Dx, :Defd, :Fn]},
        {:%{}, [line: line],
         [
           ok?: ok?,
           final_args_ok?: final_args_ok?,
           fun: fun,
           ok_fun: if(ok?, do: orig_ast),
           final_args_fun: final_args_fun,
           final_args_ok_fun: if(final_args_ok?, do: orig_ast),
           scope:
             if(scope_ast == :error,
               do:
                 Dx.Scope.Compiler.prepend_fallback_assigns(
                   {:fn, meta, [{:->, meta, [generated_args, body]}]},
                   state
                 ),
               else: {:fn, meta, [{:->, meta, [scope_args, scope_ast]}]}
             )
         ]}
      ]}}
    |> with_state(new_state)
  end

  defp args_without_guards([{:when, _, args_and_guards}]) do
    {args, _} = Enum.split(args_and_guards, -1)
    args
  end

  defp args_without_guards(args), do: args

  ## Helpers

  @compile {:inline, with_state: 2}
  defp with_state(ast, state), do: {ast, state}
end
