defmodule Dx.Test.Schema.ListCalendarOverride do
  use Ecto.Schema
  use Dx.Ecto.Schema, repo: Dx.Test.Repo

  alias Dx.Test.Schema.List

  schema "list_calendar_overrides" do
    belongs_to :list, List
    field :date, :date
    field :comment, :string

    field :hourly_points, :float
  end
end
