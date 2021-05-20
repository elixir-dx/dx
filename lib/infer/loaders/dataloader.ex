defmodule Infer.Loaders.Dataloader do
  @moduledoc """
  Uses `Dataloader` to load missing data incrementally.
  """

  def condition_data_requirements(:assoc, subject, key) do
    [{:assoc, subject, key}]
  end

  def path_data_requirements(:assoc, subject, key) do
    [{:assoc, subject, key}]
  end

  def load_data_requirements(data_reqs) do
    data_reqs
  end
end
