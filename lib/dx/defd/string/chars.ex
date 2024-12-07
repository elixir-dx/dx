defmodule Dx.Defd.String.Chars do
  @moduledoc false

  use Dx.Defd_

  @impl true
  def __dx_fun_info(_fun_name, _arity) do
    %FunInfo{args: %{all: :preload_scope}}
  end
end
