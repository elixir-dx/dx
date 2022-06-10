# References

Often times, we need to compare values in different fields with
each other, not with fixed values. This is where references come in.

Say we want to add a `by_owner?` predicate to a `Todo.Task`:

```elixir
defmodule Todo.Task do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Todo.Repo

  schema "tasks" do
    field :completed_at, :utc_datetime

    belongs_to :list, Todo.List
    belongs_to :created_by, Todo.User
  end

  infer by_owner?: true, when: %{created_by_id: {:ref, [:list, :created_by_id]}}
  infer by_owner?: false
end
```

### Operators

By default, all comparisons need to match exactly. However, other comparisons are possible as well.

Say we support completing tasks on an already archived list.
And we want to add a predicate `completed_later?` to capture that.

```elixir
defmodule Todo.Task do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Todo.Repo

  schema "tasks" do
    field :completed_at, :utc_datetime

    belongs_to :list, Todo.List
    belongs_to :created_by, Todo.User
  end

  infer completed_later?: false, when: %{completed?: false}
  infer completed_later?: false, when: %{list: %{archived?: false}}
  infer completed_later?: true, when: %{archived_at: {:gt, {:ref, [:list, :archived_at]}}}
  infer completed_later?: false
end
```

The `Todo.Task` must already by `completed?` and the `Todo.List` `archived?`.
In particular, the `Todo.Task` must be `completed_at` after the `Todo.List` was archived.

Operators can also compare to fixed values (not references).

#### Supported operators

Operators with all aliases:

- Greater than: `:gt`, `:>`, `:greater_than`, `:after`
- Greater than or equal: `:gte`, `:>=`, `:greater_than_or_equal`, `:on_or_after`, `:at_or_after`
- Less than: `:lt`, `:<`, `:less_than`, `:before`
- Less than or equal: `:lte`, `:<=`, `:less_than_or_equal`, `:on_or_before`, `:at_or_before`
