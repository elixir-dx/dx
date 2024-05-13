defmodule Dx.Util.Module do
  # Utility functions for working with modules and their functions.

  @moduledoc false

  defdelegate has_function?(module, function_name, arity), to: Kernel, as: :function_exported?
end
