defmodule Infer.Test.Schema.ListTemplate do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Infer.Test.Repo

  alias Infer.Test.Schema.List

  schema "list_templates" do
    field :title, :string

    field :hourly_points, :float

    has_many :lists, List, foreign_key: :from_template_id
  end
end
