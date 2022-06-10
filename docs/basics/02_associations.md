# Associations

Infer allows to easily traverse associations to access fields or even
predicates defined on associated records.

Say our `Todo.List` schema from the previous guide now `has_many` tasks:

```elixir
defmodule Todo.List do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Todo.Repo

  schema "lists" do
    field :archived_at, :utc_datetime

    has_many :tasks, Todo.Task
  end

  infer archived?: false, when: %{archived_at: nil}
  infer archived?: true

  infer state: :archived, when: %{archived?: true}
  infer state: :active
end
```

In return, we add a Task schema that `belongs_to` a List:

```elixir
defmodule Todo.Task do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Todo.Repo

  schema "tasks" do
    field :completed_at, :utc_datetime

    belongs_to :list, Todo.List
  end

  infer completed?: false, when: %{completed_at: nil}
  infer completed?: true
end
```

### belongs_to

Say we want a Task to be `archived?` when the List it belongs to is archived.
We could write a similar rule on the `Todo.Task` schema as we have on the List:

```elixir
  infer archived?: false, when: %{list: %{archived_at: nil}}
  infer archived?: true
```

The `archived?` predicate looks at the associated `list` (defined using `belongs_to`)
and its field `archived_at`, and compares that to `nil`.
If it's `nil` then the Task's predicate `archived?` is `false`, otherwise it's `true`.

However, since we've already defined this logic on the List, we can also use the predicate
on the associated List instead, and change things around a bit:

```elixir
  infer archived?: true, when: %{list: %{archived?: true}}
  infer archived?: false
```

#### Usage

Like before, we can use `Infer.get!/2` to evaluate the predicate,
but only if the association is (pre)loaded:

```elixir
iex> list = %Todo.List{archived_at: ~U[2022-02-02 22:22:22Z]} |> Todo.Repo.insert!()
...> %Todo.Task{completed_at: nil, list: list}
...> |> Infer.get!(:archived?)
true
```

If the association is not (pre)loaded, `Infer.get!/2` will raise an error:

```elixir
iex> list = %Todo.List{archived_at: ~U[2022-02-02 22:22:22Z]} |> Todo.Repo.insert!()
...> %Todo.Task{completed_at: nil, list: list}
...> |> Todo.Repo.insert!() |> Todo.Repo.reload!()  # insert and reload without associations
...> |> Infer.load!(:archived?)
** (Infer.Error.NotLoaded) Association list is not loaded on nil. Cannot get path: nil
```

To allow Infer to load associations as needed, use `Infer.load!/2` instead:

```elixir
iex> list = %Todo.List{archived_at: ~U[2022-02-02 22:22:22Z]} |> Todo.Repo.insert!()
...> %Todo.Task{completed_at: nil, list: list}
...> |> Todo.Repo.insert!() |> Todo.Repo.reload!()  # insert and reload without associations
...> |> Infer.load!(:archived?)
# loads the associated list
true
```

### has_many

We can also define predicates based on a `has_many` association.
Infer generally treats conditions on a list of records like an `Enum.any?` condition:

```elixir
defmodule Todo.List do
  # ...

  infer in_progress?: true, when: %{tasks: %{completed?: true}}
  infer in_progress?: false
end
```

The predicate `in_progress?` is `true` if there's any Task associated that has `completed?: true`.
Otherwise, if there's no Task associated that has `completed?: true`, `in_progress?` is `false`.

Putting it all together, we can extend our `state` predicate on the `Todo.List` schema:

```elixir
defmodule Todo.List do
  # ...

  infer state: :archived, when: %{archived?: true}
  infer state: :in_progress, when: %{tasks: %{completed?: true}}
  infer state: :ready, when: %{tasks: %{}}
  infer state: :empty
end
```

What does the `:ready` rule do?
It checks whether there's any Task, without any condition on the Task.
So if the List is not archived, and there are no completed tasks, but there is a Task,
`:state` is `:ready`. Otherwise `:state` is `:empty`.

_This might be hard to grasp, but it will hopefully become clearer in the next guide..._
