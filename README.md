# Infer

[![Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://infer-beam.github.io/infer/)
[![License](https://img.shields.io/github/license/infer-beam/infer.svg)](https://github.com/infer-beam/infer/blob/main/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/infer-beam/infer/main)](https://github.com/infer-beam/infer/tree/main)
![CI](https://github.com/infer-beam/infer/actions/workflows/ci.yml/badge.svg)

Infer is an inference engine that allows to declare logic based on data schemas (such as Ecto)
in a central and concise way.

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

## Guides

If you're new to Infer, the best place to start are the [Guides](https://infer-beam.github.io/infer/).

## Status

Infer was started at Team Engine, where we've been developing it internally since January 2021.
We've been using it in production since March 2021, and increasingly port our business logic to it.
To make it an easy-to-adopt open-source library, the next steps are to:

- [x] extract the code into this repo
- [x] re-add tests (because they were domain-specific)
- [x] write guides, a reference and an announcement
- [ ] resolve absinthe-graphql/dataloader#129 and re-add dataloader as a hex dependency
- [ ] find another name, because `infer` is [already taken](https://hex.pm/packages/infer) on hex.pm
- [ ] release on hex.pm

## Special thanks

This project is sponsored and kindly supported by [Team Engine](https://www.teamengine.co.uk/).

If you'd like to join us working on Infer and [Refinery](https://github.com/infer-beam/refinery) as a contractor, please [reach out](https://tinyurl.com/engine-infer-dev2).
