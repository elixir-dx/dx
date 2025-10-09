import Config

# Runtime configuration for database
# This file is evaluated after compilation, making it suitable for
# reading environment variables that may change between environments

if config_env() != :prod do
  config :dx, Dx.Test.Repo,
    hostname: System.get_env("POSTGRES_HOST", "localhost"),
    username: System.get_env("POSTGRES_USER", "postgres"),
    password: System.get_env("POSTGRES_PASSWORD", "postgres")
end
