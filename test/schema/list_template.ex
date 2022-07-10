defmodule Dx.Test.Schema.ListTemplate do
  use Ecto.Schema
  use Dx.Ecto.Schema, repo: Dx.Test.Repo

  alias Dx.Test.Schema.List

  schema "list_templates" do
    field :title, :string

    field :hourly_points, :float

    has_many :lists, List, foreign_key: :from_template_id
  end
end
