defmodule Infer.Test.Schema.Role do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Infer.Test.Repo

  alias Infer.Test.Schema.User

  schema "roles" do
    field :name, :string

    has_many :users, User
  end
end
