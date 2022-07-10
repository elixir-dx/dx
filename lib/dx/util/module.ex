defmodule Dx.Util.Module do
  @moduledoc """
  Utility functions for working with modules and their functions.
  """

  defdelegate has_function?(module, function_name, arity), to: Kernel, as: :function_exported?
end
