# Predicates

Dx allows you to add predicates to your schema.
Predicates are like virtual fields, but instead of storing values,
you define what the value should be, based on conditions.

### Example: boolean predicate

Say we have a ToDo list app with a `Todo.List` schema type.

```elixir
defmodule Todo.List do
  use Ecto.Schema
  use Dx.Ecto.Schema, repo: Todo.Repo

  schema "lists" do
    field :archived_at, :utc_datetime
  end

  infer archived?: false, when: %{archived_at: nil}
  infer archived?: true
end
```

Here, we define a predicate `archived?` on our `Todo.List` schema.
It has the value `false` when the field `archived_at` is `nil`.
If this condition doesn't match, Dx will look at the next rule
and assign the value `true`. Since there is no condition for this
last rule, it will always match.

> _Tip: It is a good practice to always have a last rule without
> condition to define a fallback value._

#### Usage

This predicate can now be used like a field, as long as you use an `Dx`
to to evaluate it, such as `Dx.get!/2`:

```elixir
# loading a predicate
iex> %Todo.List{archived_at: nil}
...> |> Dx.get!(:archived?)
false

iex> %Todo.List{archived_at: ~U[2022-02-02 22:22:22Z]}
...> |> Dx.get!(:archived?)
true
```

### Example: multi-value predicate

Instead of assigning `true` or `false`, we might define a predicate
`state` that can be easily extended later on.
We can even use the existing predicate and reference it in our new rule:

```elixir
defmodule Todo.List do
  use Ecto.Schema
  use Dx.Ecto.Schema, repo: Todo.Repo

  schema "lists" do
    field :archived_at, :utc_datetime
  end

  infer archived?: false, when: %{archived_at: nil}
  infer archived?: true

  infer state: :archived, when: %{archived?: true}
  infer state: :active
end
```

#### Usage

Just as with `archived?`, we can now use `state` as if it was a field when using `Dx`:

```elixir
iex> %Todo.List{archived_at: nil}
...> |> Dx.get!(:state)
:active

iex> %Todo.List{archived_at: ~U[2022-02-02 22:22:22Z]}
...> |> Dx.get!(:state)
:archived
```
