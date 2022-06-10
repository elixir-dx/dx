# Arguments

To pass in data from the caller context and make it available in the rules, there's the `args` option.
Any `args` passed to the `Infer` API function will be available in rules as if `args` was
an association on the current current root record.

Say we implement some authorization, where a user can archive a `Todo.List` only if they are an admin, or they are the owner of the list.
We pass in the currently logged-in user struct, which was already loaded as part of authentication.

```elixir
Infer.load!(list, args: [current_user: current_user])
```

The `current_user` is then available within `args`, including any
fields, associations and predicates defined on it.

```elixir
defmodule Todo.List do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Todo.Repo

  schema "lists" do
    field :archived_at, :utc_datetime

    belongs_to :created_by, Todo.User
  end

  infer can_archive?: true, when: %{args: %{current_user: %{is_admin?: true}}}
  infer can_archive?: true, when: %{created_by_id: {:ref, [:args, :current_user, :id]}}
  infer can_archive?: false
end
```
