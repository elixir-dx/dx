use Mix.Config

config :infer, Infer.Test.Repo,
  hostname: "localhost",
  username: "postgres",
  password: "postgres",
  database: "infer_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/schema"

config :infer, ecto_repos: [Infer.Test.Repo],
  repo: Infer.Test.Repo

config :logger, level: :warn
