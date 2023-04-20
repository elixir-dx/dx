defmodule Dx.Error.Timeout do
  defexception [:configured_timeout]

  def message(error) do
    """
    A timeout occurred while loading the data required.
    The timeout is currently set to #{error.configured_timeout}.
    If you are using the default `Dx.Loaders.Dataloader`, you can
    increase the timeout by passing `loader_options: [timeout: your_timeout]`
    as last argument to the `Dx` function you are using, such as `Dx.load/3`.
    """
  end
end
