defmodule Dx.Defd.String.Chars do
  @moduledoc false

  use Dx.Defd_

  @impl true
  def __dx_fun_info(_fun_name, arity) do
    %FunInfo{args: List.duplicate(:preload_scope, arity)}
  end
end
