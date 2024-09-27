# Dx

[![Hex.pm](https://img.shields.io/hexpm/v/dx)](https://hex.pm/packages/dx)
[![Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/dx/Dx.html)
[![License](https://img.shields.io/github/license/elixir-dx/dx.svg)](https://github.com/elixir-dx/dx/blob/main/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/elixir-dx/dx/main)](https://github.com/elixir-dx/dx/tree/main)
![CI](https://github.com/elixir-dx/dx/actions/workflows/ci.yml/badge.svg)

Dx enabled you to write Elixir codes as if all your Ecto data is already (pre)loaded.

Under the hood, Dx translates your code (defined using `defd`) to a version that loads
data automatically, when needed, and even translates parts of your code to database queries,
which is even more efficient, without you having to implement the data loading at all.

### Example

```elixir
defmodule MyApp.DataLogic do
  import Dx.Defd

  defd published_lists_with_no_tasks(user) do
    Enum.filter(MyApp.Schema.List, fn list ->
      list.published? and
        Enum.count(list.tasks) == 0 and
        list.created_by_id == user.id
    end)
  end
end
```

This can be called using

```elixir
Dx.Defd.load!(MyApp.DataLogic.published_lists_with_no_tasks(user))
```

and will be fully translated to a database call.

It still works the same when you call other `defd` functions,
so you can organize your code cleanly.

## Installation

Add `dx` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dx, "~> 0.3.0"}
  ]
end
```

Add this line to the top of your Ecto schema modules
(replace `MyApp.Repo` with your Ecto repo module)

```elixir
use Dx.Ecto.Schema, repo: MyApp.Repo
```

Configure your repo in `config.exs`
(replace `MyApp.Repo` with your Ecto repo module)

```elixir
config :dx, repo: MyApp.Repo
```

Import the formatter rules in `.formatter.exs`:

```elixir
[
  import_deps: [:dx]
]
```

## Background

Most server backends for web and mobile applications are split between
the actual application and at least one database. In their day-to-day
programming, most Elixir developers have to keep that in mind and think
about how to store data in the database, and when and how to load it.
It's so deeply engrained that we often take this problem for granted,
having integrated it in how we think about code and code architecture.
For example, Phoenix (the most popular web framework for Elixir) has
API contexts that suggest structuring apps into modules that act as a
boundary (or interface) to the rest of the code. Within these, data is
loaded and returned. Since it's a generic interface, the simplest
approach is to load all data that's possibly needed, and return it.
However, as the app grows in functionality and thus complexity, this
may become a lot of data. And it's still necessary to think about what
to return, where it's needed, and how to slice it.

Imagine this problem would not exist. Enter Dx.

With Dx, Elixir developers don't have to think about loading data from
the database at all. You just write Elixir code, as if all data is
already loaded and readily available.

## How it works

When working with data in the database, you define Elixir functions
using `defd` instead of `def` (the regular Elixir function definition).
The `defd` function must be imported from the `Dx.Defd` module.
Within `defd` functions, you can write regular Elixir code, accessing
all fields and associations as if they're already loaded. You can also
call other `defd` functions and structure your code in modules as usual.

When the app is compiled, Dx translates your `defd` code into multiple
versions with different ways to load data:

- **Data loading**: Any data that might need to be loaded is wrapped in a
  check that either returns the already loaded data, or returns a "data
  requirement". Dx runs the code at the entry point (the first function
  that's a `defd` function) and either receives the result, or receives
  a number of data requirements. These are loaded, using the dataloader
  library under the hood. Then the code is run again, this time either
  returning the result, or more data requirements, and so on.
- **Data querying**: Parts of the code may be translated to "data scopes",
  which are used to generate database queries out of your code. For
  example, using the standard library function `Enum.filter` in a `defd`
  function will try to translate the condition (the anonymous function
  passed as second argument) into a database query. When successful, the
  data will not be loaded and then filtered in Elixir, but will already
  be filtered in the database.

All this happens automatically in the background. Parts of the work are
done when compiling your code. Other parts are done when running it.

## Caveats

Dx is designed with great care for developer experience. You can just start
using it, and will get warnings with explanations if something should or must
be done differently. It still helps to understand the main limitations:

### Pure functions

Dx translates your code into different other versions of it. The translated
versions may then be run any number of times, more or less often than the
original would have been run. Thus, that any code defined using `defd` should
be **functionally pure**. This means, it should not have any side effects.

- When the same code is run with the same arguments, it must always return
  the same result. Examples for non-pure code are using date and time, or
  random numbers.
- `defd` functions should also not modify any external state, such as
  modifying data in the database, or printing text to the console.
  Except if it's fine that the modification is applied multiple times.

### Calling non-defd functions

You can call non-defd functions from within `defd` functions. However, Dx
can't "look into" them. No data inside them will be loaded, and they can
never be translated to database queries. They will also be run any number
of times, so they should be pure functions as well.

Dx will ask you to wrap the call in a `non_dx/1` function call. This is
just to make clear that the called function is not defined using `defd`
when reading the code.

### Finding good entry points

Any time a `defd` function is called from a regular Elixir function,
that's an **entry point**. That's where any needed data will be loaded.

Dx will ask you to wrap the call in a `Dx.Defd.load!/1` function call.
This is just to make clear that the called function is an entry point
to `defd` land and data may be loaded here.

It may help to create dedicated modules for all `defd` functions. They
are usually the core of the application, with much of the (business) logic.
Any code calling into them - the entry points - in contrast, are outside
these modules, for example in a API function, a Phoenix controller, or an
Oban worker. This is where the data is loaded, whereas the `defd` modules
consist only of pure functions with (business) logic.

### Filter conditions in Elixir vs. SQL

Conditions can behave quite differently in SQL vs. Elixir.
In the future, Dx will fully translate all nuances correctly, but for now,
you have to keep that in mind yourself.

- `NULL` never matches anything in SQL, but it does in Elixir.
  For example, `title != "TODO"` when `title = nil` will match in Elixir,
  but not match in SQL. Thus, `nil` cases must be handled individually:
  `is_nil(title) or title != "TODO"`
- Dx joins `has_one` and `belongs_to` associations using `LEFT JOIN` in
  SQL. This means, you can happily access association chains, even if
  interim assocation parts do not exist. This would crash in Elixir, but
  in SQL, all fields just appear as `NULL`. Thus, the presence of
  associations should be checked individually:
  `not is_nil (list.creator) and is_nil(list.creator.deleted_at)`

## Currently supported

### Syntax

- Defining functions using `defd`
  - with multiple clauses
  - with patterns in arguments
  - without guards
- Calling all `Enum` functions
- Calling all `Kernel` functions without a function argument
- `fn` without patterns in arguments or guards
- `case` with patterns
- `cond`

### Translatable to database queries

#### Functions

- `Enum.count/1`
- `Enum.filter/2`

will be translated to database queries, if both

- the first argument is either
  - a schema module, f.ex. `Enum.filter(Todo.Task, fn task -> task.priority == "high")`
  - the result of another function listed above
- the function passed as second argument (if any) consists only of functions listed above or:
  - `==`, `<`, `>`
  - `and`, `or`, `&&`
  - `Enum.any?/2`, `Enum.all?/2`
  - `DateTime.compare/2`

### Roadmap

Check the [Dx roadmap board](https://github.com/orgs/elixir-dx/projects/1)
for updates.

## inferred schema fields (deprecated)

Dx is an Elixir library that allows adding inferred properties to Ecto schemas,
defined by rules based on fields, associations or other inferred properties.
You can then load/query them as if they were Ecto fields or associations using Dx's API.

It allows you to write declarative and easy-to-read domain logic by defining WHAT the
rules are without having to care about HOW to execute them.

Under the hood, Dx's evaluation engine loads associations as needed concurrently in batches and
can even translate your logic to Ecto queries directly.

If you're new to Dx, the best place to start are the [Guides](https://hexdocs.pm/dx/welcome.html).

## Special thanks

This project was initially sponsored and kindly supported by [Team Engine](https://www.teamengine.co.uk/).
