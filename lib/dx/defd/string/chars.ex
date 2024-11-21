defmodule Dx.Defd.String.Chars do
  @moduledoc false

  use Dx.Defd.Ext

  @impl true
  def __fun_info(_fun_name, arity) do
    %FunInfo{args: List.duplicate(:preload_scope, arity)}
  end
end
