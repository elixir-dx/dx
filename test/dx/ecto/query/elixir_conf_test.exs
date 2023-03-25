defmodule Dx.Ecto.ElixirConfTest do
  use Dx.Test.DataCase, async: true

  alias Dx.Ecto.Query
  alias Dx.Test.Repo

  import Ecto.Query

  setup do
    archived_at = DateTime.utc_now() |> DateTime.truncate(:second)
    list = create(List, %{archived_at: archived_at, created_by: %{}})

    list2 =
      create(List, %{
        title: "FANCY TEMPLATE",
        from_template: %{title: "FANCY TEMPLATE"},
        created_by: %{}
      })

    tasks =
      Enum.map(0..1, fn i ->
        create(Task, %{list_id: list.id, due_on: today(i), created_by_id: list.created_by_id})
      end)

    [
      list: list,
      list2: list2,
      archived_at: archived_at,
      title: list.title,
      title2: list2.title,
      tasks: tasks
    ]
  end

  test "" do
    from(l in List,
      select: %{
        name: l.name,
        task_count: count(assoc(l, :tasks))
      }
    )
  end
end
