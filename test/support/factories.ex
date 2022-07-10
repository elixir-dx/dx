defmodule Test.Support.Factories do
  use Refinery, repo: Dx.Test.Repo

  def refinement(Dx.Test.Schema.User, :default) do
    %{
      email: "alice@acme.org"
    }
  end

  def refinement(Dx.Test.Schema.List, :default) do
    %{
      title: "My List"
    }
  end

  def refinement(Dx.Test.Schema.ListTemplate, :default) do
    %{
      title: "My List Template"
    }
  end

  def refinement(Dx.Test.Schema.Task, :default) do
    %{
      title: "My Task"
    }
  end
end
