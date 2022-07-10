defmodule Dx.Test.Schema.Role do
  use Ecto.Schema
  use Dx.Ecto.Schema, repo: Dx.Test.Repo

  alias Dx.Test.Schema.User

  schema "roles" do
    field :name, :string

    has_many :users, User
  end
end
