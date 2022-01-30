defmodule Infer.Test.Schema.List do
  use Ecto.Schema

  alias Infer.Test.Schema.User

  schema "lists" do
    field :title, :string

    belongs_to :created_by, User

    field :archived_at, :utc_datetime
    timestamps()
  end
end
