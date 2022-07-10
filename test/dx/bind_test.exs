defmodule Dx.BindTest do
  use ExUnit.Case, async: true

  alias Dx.Test.Schema.{User, List}
  import Test.Support.Factories

  defmodule TestStruct do
    defstruct [:field]
  end

  defmodule ListRules do
    use Dx.Rules, for: List

    infer :by_author?, when: %{created_by_id: {:ref, [:args, :created_by_id]}}
  end

  defmodule UserRules do
    use Dx.Rules, for: User

    infer latest_data_for_author: {:bound, :result},
          when: %{lists: {:bind, :result, %{created_by_id: {:ref, [:args, :created_by_id]}}}}

    infer nested_data_for_author: %{might: [1, 2, 3, %TestStruct{field: {:bound, :result}}]},
          when: %{lists: {:bind, :result, %{created_by_id: {:ref, [:args, :created_by_id]}}}}

    infer failing_data_for_author: %{might: [1, 2, 3, %TestStruct{field: {:bound, :result}}]},
          when: %{lists: %{created_by_id: {:ref, [:args, :created_by_id]}}}

    infer fallback_data_for_author: %{
            preferred: {:bound, :preferred, nil},
            fallback: {:bound, :fallback, nil}
          },
          when: [
            %{lists: {:bind, :preferred, %{created_by_id: {:ref, [:args, :created_by_id]}}}},
            %{lists: {:bind, :fallback, %{title: "No 5"}}}
          ]

    import_rules ListRules

    infer indirect_data_for_author: {:bound, :result},
          when: {:bind, :result, %{lists: {:bind, :result, :by_author?}}}
  end

  setup do
    list1 = build(List, %{created_by_id: 1, title: "No 1"})
    list2 = build(List, %{created_by_id: 2, title: "No 2"})
    list3 = build(List, %{created_by_id: 3, title: "No 3"})
    list4 = build(List, %{created_by_id: 3, title: "No 4"})
    list5 = build(List, %{created_by_id: 4, title: "No 5"})
    user = build(User, %{lists: [list1, list2, list3, list4, list5]})

    [
      user: user,
      list1: list1,
      list2: list2,
      list3: list3,
      list4: list4,
      list5: list5
    ]
  end

  test "returns bound value on root level of the assigns", %{user: user, list2: list2} do
    assert Dx.get!(user, :latest_data_for_author,
             extra_rules: UserRules,
             args: [created_by_id: 2]
           ) ==
             list2
  end

  test "returns first bound value", %{user: user, list3: list3} do
    assert Dx.get!(user, :latest_data_for_author,
             extra_rules: UserRules,
             args: [created_by_id: 3]
           ) ==
             list3
  end

  test "returns nil when no match", %{user: user} do
    assert Dx.get!(user, :latest_data_for_author,
             extra_rules: UserRules,
             args: [created_by_id: 0]
           ) ==
             nil
  end

  test "returns bound value in nested assigns", %{user: user, list2: list2} do
    assert Dx.get!(user, :nested_data_for_author,
             extra_rules: UserRules,
             args: [created_by_id: 2]
           ) ==
             %{might: [1, 2, 3, %TestStruct{field: list2}]}
  end

  test "fails when using unbound key", %{user: user} do
    assert_raise(KeyError, fn ->
      Dx.get!(user, :failing_data_for_author, extra_rules: UserRules, args: [created_by_id: 2])
    end)
  end

  test "returns default value when given and no match", %{
    user: user,
    list2: list2,
    list5: list5
  } do
    assert Dx.get!(user, :fallback_data_for_author,
             extra_rules: UserRules,
             args: [created_by_id: 2]
           ) ==
             %{preferred: list2, fallback: nil}

    assert Dx.get!(user, :fallback_data_for_author,
             extra_rules: UserRules,
             args: [created_by_id: 0]
           ) ==
             %{preferred: nil, fallback: list5}
  end

  describe "matching associated predicate" do
    test "returns bound value on root level of the assigns", %{user: user} do
      assert Dx.get!(user, :indirect_data_for_author,
               extra_rules: UserRules,
               args: [created_by_id: 2]
             ) ==
               user
    end

    test "returns first bound value", %{user: user} do
      assert Dx.get!(user, :indirect_data_for_author,
               extra_rules: UserRules,
               args: [created_by_id: 3]
             ) ==
               user
    end

    test "returns nil when no match", %{user: user} do
      assert Dx.get!(user, :indirect_data_for_author,
               extra_rules: UserRules,
               args: [created_by_id: 0]
             ) ==
               nil
    end
  end
end
