# Dx

[![Hex.pm](https://img.shields.io/hexpm/v/dx)](https://hex.pm/packages/dx)
[![Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/dx/Dx.html)
[![License](https://img.shields.io/github/license/dx-beam/dx.svg)](https://github.com/dx-beam/dx/blob/main/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/dx-beam/dx/main)](https://github.com/dx-beam/dx/tree/main)
![CI](https://github.com/dx-beam/dx/actions/workflows/ci.yml/badge.svg)

Dx is an Elixir library that allows adding inferred properties to Ecto schemas,
defined by rules based on fields, associations or other inferred properties.
You can then load/query them as if they were Ecto fields or associations using Dx's API.

It allows you to write declarative and easy-to-read domain logic by defining WHAT the
rules are without having to care about HOW to execute them.

Under the hood, Dx's evaluation engine loads associations as needed concurrently in batches and
can even translate your logic to Ecto queries directly.

## Installation

Add `dx` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dx, github: "dx-beam/dx"}
  ]
end
```

When running Dx within transactions, please also add the following, until absinthe-graphql/dataloader#129 is closed:

```elixir
def deps do
  [
    {:dataloader, github: "arnodirlam/dataloader", branch: "async-option", override: true}
  ]
end
```

Configure your repo in `config.exs`:

```elixir
config :dx, repo: MyApp.Repo
```

Import the formatter rules in `.formatter.exs`:

```elixir
[
  import_deps: [:dx]
]
```

## Guides

If you're new to Dx, the best place to start are the [Guides](https://dx-beam.github.io/dx/).

## Status

Dx was started at Team Engine, where we've been developing it internally since January 2021.
We've been using it in production since March 2021, and increasingly port our business logic to it.
To make it an easy-to-adopt open-source library, the next steps are to:

- [x] extract the code into this repo
- [x] re-add tests (because they were domain-specific)
- [x] write guides, a reference and an announcement
- [ ] resolve absinthe-graphql/dataloader#129 and re-add dataloader as a hex dependency
- [x] find another name, because `infer` is [already taken](https://hex.pm/packages/infer) on hex.pm
- [x] release on hex.pm

## Special thanks

This project is sponsored and kindly supported by [Team Engine](https://www.teamengine.co.uk/).

If you'd like to join us working on Dx and [Refinery](https://github.com/dx-beam/refinery) as a contractor, please [reach out](https://tinyurl.com/engine-infer-dev2).
