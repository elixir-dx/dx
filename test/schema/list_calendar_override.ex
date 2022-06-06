defmodule Infer.Test.Schema.ListCalendarOverride do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Infer.Test.Repo

  alias Infer.Test.Schema.List

  schema "list_calendar_overrides" do
    belongs_to :list, List
    field :date, :date

    field :hourly_points, :float
  end
end
