defmodule Infer.Test.Schema.User do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Infer.Test.Repo

  alias Infer.Test.Schema.List

  schema "users" do
    field :email, :string

    field :first_name, :string
    field :last_name, :string

    has_many :lists, List, foreign_key: :created_by_id
  end

  infer full_name: {&Enum.join/1, [[{:ref, :first_name}, {:ref, :last_name}]]}
end
