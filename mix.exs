defmodule Infer.MixProject do
  use Mix.Project

  @source_url "https://github.com/infer-beam/infer"
  @version "0.3.0"

  def project do
    [
      app: :infer,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      aliases: aliases(),
      deps: deps(),
      docs: docs()
    ]
  end

  defp package do
    [
      description: "Inference engine written in Elixir",
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Arno Dirlam"],
      licenses: ["MIT"],
      links: %{
        Changelog: "https://hexdocs.pm/infer/changelog.html",
        GitHub: @source_url
      }
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger] ++ test_apps(Mix.env())
    ]
  end

  defp test_apps(:test) do
    [:ecto_sql, :postgrex]
  end

  defp test_apps(_), do: []

  defp deps do
    [
      # util
      {:typed_struct, ">= 0.0.0"},
      {:dataloader, github: "arnodirlam/dataloader", branch: "async-option"},

      # adapters
      {:ecto, ">= 3.4.3 and < 4.0.0", optional: true},
      {:ecto_sql, "~> 3.0", optional: true},

      # dev & test
      {:postgrex, "~> 0.14", only: :test, runtime: false},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end

  def docs do
    [
      extras: [
        "README.md"
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
