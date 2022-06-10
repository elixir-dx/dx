defmodule Test.Support.Factories do
  use Refinery, repo: Infer.Test.Repo

  def refinement(Infer.Test.Schema.User, :default) do
    %{
      email: "alice@acme.org"
    }
  end

  def refinement(Infer.Test.Schema.List, :default) do
    %{
      title: "My List"
    }
  end

  def refinement(Infer.Test.Schema.ListTemplate, :default) do
    %{
      title: "My List Template"
    }
  end

  def refinement(Infer.Test.Schema.Task, :default) do
    %{
      title: "My Task"
    }
  end
end
