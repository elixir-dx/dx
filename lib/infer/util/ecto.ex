defmodule Infer.Util.Ecto do
  @moduledoc """
  Utility functions to inspect Ecto schemas.

  See: https://hexdocs.pm/ecto/Ecto.Schema.html#module-reflection
  """

  def association_names(module) do
    module.__schema__(:associations)
  end

  def association_details(module, assoc) do
    module.__schema__(:association, assoc)
  end

  def field_details(module, field) do
    module.__schema__(:type, field)
  end

  def association_type(module, assoc) do
    case association_details(module, assoc) do
      %{related: type} -> type
      _else -> nil
    end
  end
end
