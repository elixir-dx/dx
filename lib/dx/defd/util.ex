# Utility functions used in multiple Defd-related modules.
defmodule Dx.Defd.Util do
  @moduledoc false

  @defd_exports_key :__defd_exports__

  def defd_name(name), do: :"__defd:#{name}__"
  def final_args_name(name), do: :"__final_args:#{name}__"
  def scope_name(name), do: :"__scope:#{name}__"

  def is_scopable?(module, fun_name, arity) do
    Code.ensure_loaded(module)
    function_exported?(module, :__scopable?, 2) and module.__scopable?(fun_name, arity)
  end

  def scopable_args(module, fun_name, arity) do
    Code.ensure_loaded(module)

    if function_exported?(module, :__scopable_args, 2) do
      module.__scopable_args(fun_name, arity)
    else
      []
    end
  end

  def is_defd?(module, fun_name, arity) do
    Code.ensure_loaded(module)

    case get_defd_exports(module) do
      {:ok, exports} ->
        Map.has_key?(exports, {fun_name, arity})

      :error ->
        function_exported?(module, defd_name(fun_name), arity + 1)
    end
  end

  defp get_defd_exports(module) do
    {:ok, Module.get_attribute(module, @defd_exports_key, %{})}
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
end
