# Thinking in Infer

When working with Infer, we have to think top-down, as opposed to bottom-up.
We always start from the end result, which we want to achieve.
Any logic and inputs needed to get to the end result are defined within Infer.

### Example

Say we have a complex requirement to implement:

> A user can archive a Todo list, but only if they created it, or if they have an "admin" role,
> and only if all tasks in the list are completed.

Let's assume we only have the schema, and no other functions, helpers, or rules defined.

```elixir
defmodule Todo.User do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Todo.Repo

  schema "users" do
    has_many :roles, Todo.UserRole
  end
end

defmodule Todo.UserRole do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Todo.Repo

  schema "user_roles" do
    field :name, Ecto.Enum, values: [:moderator, :admin, :super_admin]

    belongs_to :user, Todo.User
  end
end

defmodule Todo.List do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Todo.Repo

  schema "lists" do
    field :archived_at, :utc_datetime

    belongs_to :created_by, Todo.User
  end
end

defmodule Todo.Task do
  use Ecto.Schema
  use Infer.Ecto.Schema, repo: Todo.Repo

  schema "tasks" do
    field :completed_at, :utc_datetime

    belongs_to :list, Todo.List
  end
end
```

The inputs are the `list` to be archived and the `current_user` who tries to archive it.
The end result is either the now archived list, or an error.

Without Infer, we'd write a function that takes the `list` and the `user` who tries to archive it.
We'd then have to think about **how** to load the data needed to compute the result, and implement it.

With Infer, we don't have to think about **how** to load the data or compute the result.
Instead, we focus entirely on **what** is relevant and write the rules to represent this logic.
Infer then takes care of loading data as needed, in an efficient way.

Thinking in Infer, we usually take the following steps:

1.  What are the possible end results that we need to continue in our other code, f.ex. a web request?
    In our example, the end result can be either "archive the list" or "can't archive list".
    In code terms, we could return `true` or `false`, or we could return `:ok` or `{:error, reason}`.

    _Note:_ We think of Infer as read-only; we don't perform an action (such as archiving a list),
    but prepare and compute all the data needed to do it.

2.  What is the primary data point, on which to operate on?
    In our example, it's rather easy: we operate on a `list`.
    In other cases, there might be multiple candidates; in these cases, it might help to ask
    what data type feels most intuitive to return the end results conceived in step 1.

3.  Define a predicate on the main data type from step 2 with the possible values from step 1.
    In the code where the outcome is used, f.ex. a web request, call `Infer` with the main data point
    and this predicate. We also add additional data needed as `args`.

    In our example:

        # in Todo.List
        infer archivable?: :ok
        infer archivable?: {:error, :unauthorized}
        infer archivable?: {:error, :pending_tasks}

        # in the List controller
        with :ok <- Infer.load!(list, :archivable?, args: [current_user: current_user]),
             {:ok, archived_list} <- List.archive(list) do
          render(conn, "show.html", list: archived_list)
        end

4.  Flesh out the conditions for the various cases. For each condition, think about what's needed
    and how it could be called. If there's a good answer, use the term in the condition as if it
    already existed. This way, it's easier to stay on the requirements level, using terms that make
    sense in the app's domain.

    In our example, we also reverse the order, checking all error cases first,
    and returning `:ok` otherwise:

        # in Todo.List
        infer archivable?: {:error, :unauthorized}, when: %{can_archive?: false}
        infer archivable?: {:error, :pending_tasks}, when: %{tasks: %{completed?: false}}
        infer archivable?: :ok

5.  Define the predicates you used on the correct schema types, and continue the process until the
    requirements are fully defined using rules.

    In our example, the final set of rules might look like this:

        # in Todo.List
        infer archivable?: {:error, :unauthorized}, when: %{can_archive?: false}
        infer archivable?: {:error, :pending_tasks}, when: %{tasks: %{completed?: false}}
        infer archivable?: :ok

        infer can_archive?: true, when: %{args: %{current_user: %{is_admin?: true}}}
        infer can_archive?: true, when: %{is_owner?: true}
        infer can_archive?: false

        infer is_owner?: true, when: %{created_by_id: {:ref, [:args, :current_user, :id]}}
        infer is_owner?: false

        # in Todo.User
        infer is_admin?: true, when: %{roles: %{name: [:admin, :super_admin]}}
        infer is_admin?: false

        # in Todo.Task
        infer completed?: true, when: %{completed_at: {:not, nil}}
        infer completed?: false

### Other use cases covered

We could use the rules we defined to cover other use cases as well:

#### Filtering archivable lists

Say we have a list of `Todo.List` structs, and want to keep only the ones that can be archived,
for example to implement a web request to archive multiple lists. We use `Infer.filter/3` for it,
which takes a list of data as well as a condition, just like the ones we use when defining rules:

```elixir
Infer.filter(lists, %{archivable?: :ok}, args: [current_user: current_user])
```

#### Querying all archivable lists

Say we want to query all lists that a given user can archive. We use `Infer.query_all/3` for it,
which takes a type as well as a condition, just like the ones we use when defining rules:

```elixir
Infer.query_all(Todo.List, %{archivable?: :ok}, args: [current_user: current_user])
```
