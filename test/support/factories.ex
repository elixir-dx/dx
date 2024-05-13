defmodule Test.Support.Factories do
  use Refactory, repo: Dx.Test.Repo

  def trait(Dx.Test.Schema.User, :default) do
    %{
      email: "alice@acme.org"
    }
  end

  def trait(Dx.Test.Schema.List, :default) do
    %{
      title: "My List"
    }
  end

  def trait(Dx.Test.Schema.ListTemplate, :default) do
    %{
      title: "My List Template"
    }
  end

  def trait(Dx.Test.Schema.Task, :default) do
    %{
      title: "My Task"
    }
  end
end
