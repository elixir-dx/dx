defmodule Infer.Test.Schema.Task do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Infer.Test.Repo

  alias Infer.Test.Schema.{List, User}

  schema "tasks" do
    field :title, :string
    field :desc, :string

    belongs_to :list, List
    belongs_to :created_by, User

    field :due_on, :date
    field :completed_at, :utc_datetime
    field :archived_at, :utc_datetime
    timestamps()
  end
end
