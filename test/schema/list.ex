defmodule Infer.Test.Schema.List do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Infer.Test.Repo

  alias Infer.Test.Schema.{ListTemplate, Task, User}

  schema "lists" do
    field :title, :string

    belongs_to :created_by, User
    belongs_to :from_template, ListTemplate
    has_many :tasks, Task

    field :archived_at, :utc_datetime
    field :hourly_points, :float
    timestamps()
  end
end
