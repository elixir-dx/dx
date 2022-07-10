defmodule Dx.Test.Repo do
  use Ecto.Repo,
    otp_app: :dx,
    adapter: Ecto.Adapters.Postgres
end
