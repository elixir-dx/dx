defmodule Dx.Test.Schema.List do
  use Ecto.Schema
  use Dx.Ecto.Schema, repo: Dx.Test.Repo

  alias Dx.Test.Schema.{ListTemplate, Task, User}

  schema "lists" do
    field :title, :string
    field :published?, :boolean

    belongs_to :created_by, User
    belongs_to :from_template, ListTemplate
    has_many :tasks, Task

    field :archived_at, :utc_datetime
    field :hourly_points, :float
    timestamps()
  end
end
