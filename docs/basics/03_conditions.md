# Conditions

We've already seen some conditions nested using maps.

### And

Using maps is the go-to way of writing conditions. If you're unsure
about how to define a condition, use a `Map`.

When using a `Map` with multiple elements in a condition, all of its
elements must match for the whole condition to match. This is
similar to pattern-matching in Elixir code.

Say we want a `Todo.List` to only be `archivable?` if it's not
archived yet **and** all of its tasks are completed.

```elixir
defmodule Todo.List do
  use Ecto.Schema
  use Dx.Ecto.Schema, repo: Todo.Repo

  schema "lists" do
    field :archived_at, :utc_datetime

    belongs_to :created_by, Todo.User
  end

  infer archived?: false, when: %{archived_at: nil}
  infer archived?: true

  infer archivable?: true,
        when: %{
          archived?: false,
          tasks: {:all?, %{completed?: true}}
        }

  infer archivable?: false
end
```

### Or

A logical "or" is expressed by an Elixir `List`. This is the first
major difference to pattern-matching. It might not feel intuitive
at first, but gets familiar fast and becomes very useful once you
got used to it.

Say we want a `Todo.List` to be `archivable?` if its `:state` we
defined in the previous chapter is either `:completed` or `:ready`.

```elixir
defmodule Todo.List do
  # ...

  infer state: :archived, when: %{archived?: true}
  infer state: :completed, when: %{tasks: {:all?, %{completed?: true}}}
  infer state: :in_progress, when: %{tasks: %{completed?: true}}
  infer state: :ready, when: %{tasks: %{}}
  infer state: :empty

  infer archivable?: true, when: %{state: [:completed, :ready]}
  infer archivable?: false
end
```

This is also a good example for defining predicates based on other
predicates if they reflect how you actually think about them.
Dx will find an efficient way to evaluate them.

### Not

Negations can be expressed by wrapping a condition in a `:not` tuple.

Another way of expressing the `archived?` predicate from the first
guide would thus be:

```elixir
defmodule Todo.List do
  # ...

  infer archived?: true, when: %{archived_at: {:not, nil}}
  infer archived?: false

  # previously:
  # infer archived?: false, when: %{archived_at: nil}
  # infer archived?: true
end
```
