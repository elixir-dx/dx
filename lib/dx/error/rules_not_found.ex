defmodule Dx.Error.RulesNotFound do
  defexception [:module, :compiled]

  def message(error) do
    compiled = error.compiled || Code.ensure_compiled(error.module)

    case compiled do
      {:module, _module} ->
        "Module #{inspect(error.module)} does not define any rules"

      {:error, e} ->
        "Module #{inspect(error.module)} is not compiled, error: #{inspect(e)}"
    end
  end
end
