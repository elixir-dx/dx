defmodule Dx.Defd.Util do
  @moduledoc """
  Utility functions used in multiple Defd-related modules.
  """

  alias Dx.Defd.Result

  @defd_exports_key :__defd_exports__

  def defd_name(name), do: :"__defd:#{name}__"

  def maybe_call_defd(module, fun_name, args, eval) do
    Code.ensure_loaded(module)
    defd_name = defd_name(fun_name)
    arity = length(args)

    if function_exported?(module, defd_name, arity) do
      apply(module, defd_name, args ++ [eval])
    else
      {:ok, apply(module, fun_name, args)}
    end
  end

  def is_defd?(module, fun_name, arity) do
    case get_defd_exports(module) do
      {:ok, exports} ->
        Map.has_key?(exports, {fun_name, arity})

      :error ->
        Code.ensure_loaded(module)
        function_exported?(module, defd_name(fun_name), arity + 1)
    end
  end

  defp get_defd_exports(module) do
    {:ok, Module.get_attribute(module, @defd_exports_key)}
  rescue
    e ->
      case e do
        %ArgumentError{message: "could not call Module.get_attribute/2 because the module " <> _} ->
          :error

        _else ->
          reraise e, __STACKTRACE__
      end
  end

  def has_function?(module, fun_name, arity) do
    Module.defines?(module, {fun_name, arity})
  rescue
    e ->
      case e do
        %ArgumentError{message: "could not call Module.defines?/2 because the module " <> _} ->
          Code.ensure_loaded(module)
          function_exported?(module, fun_name, arity)

        _else ->
          reraise e, __STACKTRACE__
      end
  end

  def fetch(map, val, key, eval) do
    case val do
      %Ecto.Association.NotLoaded{} ->
        eval.loader.lookup(eval.cache, {:assoc, map, key}, false)

      other ->
        Result.ok(other)
    end
  end
end
