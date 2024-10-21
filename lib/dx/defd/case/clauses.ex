defmodule Dx.Defd.Case.Clauses do
  @moduledoc false

  alias Dx.Defd.Ast

  @doc """
  Converts function clauses to case clauses by wrapping the arguments.
  """
  def from_fn_clauses(clauses) do
    Enum.map(clauses, fn
      {:->, meta, [[{:when, when_meta, args_and_guards}], body]} ->
        {args, [guards]} = Enum.split(args_and_guards, -1)
        {:->, meta, [[{:when, when_meta, [Ast.wrap_args(args), guards]}], body]}

      {:->, meta, [args, body]} ->
        {:->, meta, [[Ast.wrap_args(args)], body]}
    end)
  end

  @doc """
  Converts case clauses back to function clauses by unwrapping the arguments.

  ## Parameters
    - case_clauses: List of case clauses to convert.
    - fn_args: Function arguments to use for unwrapping, without guards.
    - mapper: Optional function to apply to the body of each clause. Defaults to identity function.
  """
  def to_fn_clauses(case_clauses, fn_args, mapper \\ &Function.identity/1) do
    Enum.map(case_clauses, fn
      {:->, meta, [[{:when, when_meta, [wrapped_args, guards]}], body]} ->
        unwrapped_args = Ast.unwrap_args(wrapped_args, fn_args)
        {:->, meta, [[{:when, when_meta, unwrapped_args ++ [guards]}], mapper.(body)]}

      {:->, meta, [[wrapped_args], body]} ->
        {:->, meta, [Ast.unwrap_args(wrapped_args, fn_args), mapper.(body)]}
    end)
  end

  @doc """
  Unwraps clauses if all return {:ok, ...}

  ## Returns
    {:ok, unwrapped_clauses} if all clauses are successfully unwrapped,
    :error if any clause doesn't match the expected format.
  """
  def to_ok_clauses(clauses, result \\ {:ok, []})

  def to_ok_clauses([], {:ok, result}) do
    {:ok, :lists.reverse(result)}
  end

  def to_ok_clauses([{:->, meta, [[pattern], {:ok, ast}]} | rest], {:ok, result}) do
    to_ok_clauses(rest, {:ok, [{:->, meta, [[pattern], ast]} | result]})
  end

  def to_ok_clauses(_, _) do
    :error
  end
end
