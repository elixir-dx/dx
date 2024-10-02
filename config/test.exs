import Config

config :dx, Dx.Test.Repo,
  hostname: "localhost",
  username: "postgres",
  password: "postgres",
  database: "dx_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/schema"

config :dx, ecto_repos: [Dx.Test.Repo],
  repo: Dx.Test.Repo

config :logger, level: :warning
# config :logger, :console, format: {PrettyPrintFormatter, :write}
