defmodule Dx.Test.Schema.RoleAuditLog do
  use Ecto.Schema
  use Dx.Ecto.Schema, repo: Dx.Test.Repo

  alias Dx.Test.Schema.Role
  alias Dx.Test.Schema.User

  schema "role_audit_logs" do
    field :event, Ecto.Enum, values: ~w(role_added role_removed)a

    belongs_to :role, Role
    belongs_to :assignee, User
    belongs_to :actor, User

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
