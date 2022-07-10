defmodule Dx.Rules.ListOwnerTest do
  use Dx.Test.DataCase

  defmodule Rules do
    use Dx.Rules, for: Task

    infer :created_by_list_owner?,
      when: %{created_by: %{id: {:ref, [:list, :created_by_id]}}}

    infer created_by_list_owner?: false
  end

  setup do
    user = create(User)

    list = create(List, %{created_by: user})

    [user: user, list: list]
  end

  test "created by list owner", %{user: user, list: list} do
    task = create(Task, %{list_id: list.id, created_by_id: user.id})

    assert %Ecto.Association.NotLoaded{} = task.list

    assert Dx.load!(task, :created_by_list_owner?, extra_rules: Rules)
  end

  test "created by other user", %{list: list} do
    other_user = create(User)
    task = create(Task, %{list_id: list.id, created_by_id: other_user.id})

    assert %Ecto.Association.NotLoaded{} = task.list

    assert Dx.load!(task, :created_by_list_owner?, extra_rules: Rules) == false
  end
end
