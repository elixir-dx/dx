defmodule Infer.Test.Repo.Migrations.CreateBaseSchema do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :first_name, :string
      add :last_name, :string
    end

    create table(:lists) do
      add :title, :string, null: false
      add :created_by_id, references(:users), null: false

      add :archived_at, :utc_datetime
      timestamps()
    end

    create table(:tasks) do
      add :title, :string, null: false
      add :desc, :string

      add :list_id, references(:lists), null: false
      add :created_by_id, references(:users), null: false

      add :completed_at, :utc_datetime
      add :archived_at, :utc_datetime
      timestamps()
    end
  end
end
