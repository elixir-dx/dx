# Infer

[![Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://infer-beam.github.io/infer/)
[![License](https://img.shields.io/github/license/infer-beam/infer.svg)](https://github.com/infer-beam/infer/blob/main/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/infer-beam/infer/main)](https://github.com/infer-beam/infer/tree/main)
![CI](https://github.com/infer-beam/infer/actions/workflows/ci.yml/badge.svg)

Infer is an inference engine that allows to declare logic based on data schemas (such as Ecto)
in a central and concise way.

## Guides

The guides can be found at [infer-beam.github.io/infer](https://infer-beam.github.io/infer/).

## Installation

Add `infer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:infer, github: "infer-beam/infer"}
  ]
end
```

Configure your repo in `config.exs`:

```elixir
config :infer, repo: MyApp.Repo
```

Import the formatter rules in `.formatter.exs`:

```elixir
[
  import_deps: [:infer]
]
```

## Why Infer?

Infer offers a declarative approach to application logic that especially shines in apps with:

- Complex data schemas, especially when rules need to look at data in many multiple or deeply
  nested associated types/modules
- Complex application logic, especially with many "edge cases" and other conditional logic
- Large parts of the data being loaded (e.g. from the database) is only needed to compute final
  results

Infer helps in these cases, because:

- Application logic is declared in a concise and clean way that's readable even to
  non-developers (with a short introduction)
- Application logic can be laid out into modules as it makes sense for the application domain, not the code
- No execution code needs to be written, just call `Infer` with a single or list of records and
  the desired results, and it will compute them
- Infer loads required data as needed (e.g. from the database), in an optimized way that applies
  filtering, batching and concurrency, and avoids overfetching

## Status

Infer is sponsored by Team Engine, where we've been developing it internally since January 2021.
We've been using it in production since March 2021, and increasingly port our business logic to it.
To make it an easy-to-adopt open-source library, the next steps are to:

- [x] extract the code into this repo
- [x] re-add tests (because they were domain-specific)
- [x] write guides, a reference and an announcement
- [ ] resolve absinthe-graphql/dataloader#129 and re-add dataloader as a hex dependency
- [ ] release on hex.pm
