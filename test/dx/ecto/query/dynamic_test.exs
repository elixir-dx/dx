defmodule Dx.Ecto.DynamicTest do
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

  # test "select comparison" do
  #   static = from(t in Task, select: %{title: t.title, same: t.title == t.desc, desc: t.desc})

  #   # assert Query.to_sql(Repo, static) =~ """
  #   #        SELECT l0."archived_at" FROM \
  #   #        """

  #   assert [
  #     %{title: "My Task", desc: nil, same: false},
  #     %{title: "My Task", desc: nil, same: false},
  #   ] = Repo.all(static)
  # end

  test "static fields", %{archived_at: archived_at} do
    static = from(l in List, as: :list, select: [:archived_at])

    assert Query.to_sql(Repo, static) =~ """
           SELECT l0."archived_at" FROM \
           """

    assert [%{archived_at: ^archived_at}, %{title: nil}] = Repo.all(static)
  end

  test "merge static fields", %{archived_at: archived_at, title: title, title2: title2} do
    static = from(l in List, as: :list, select: [:archived_at], select_merge: [:title])

    assert Query.to_sql(Repo, static) =~ """
           SELECT l0."archived_at", l0."title" FROM \
           """

    assert [%{archived_at: ^archived_at, title: ^title}, %{archived_at: nil, title: ^title2}] =
             Repo.all(static)
  end

  test "merge static map", %{archived_at: archived_at, title: title, title2: title2} do
    static =
      from(
        l in List,
        as: :list,
        select: %{},
        select_merge: %{a: map(l, [:archived_at])},
        select_merge: %{c: map(l, [:title])}
      )

    assert Query.to_sql(Repo, static) =~ """
           SELECT l0."archived_at", l0."title" FROM \
           """

    assert [
             %{a: %{archived_at: ^archived_at}, c: %{title: ^title}},
             %{a: %{archived_at: nil}, c: %{title: ^title2}}
           ] = Repo.all(static)
  end

  test "from subquery", %{title: title, title2: title2} do
    subquery = select(List, [l], %{t: l.title, l: "literal"})

    query =
      from(l in subquery(subquery),
        select: %{x: l.t, y: l.l, z: "otherliteral"}
      )

    assert [
             %{x: ^title, y: "literal", z: "otherliteral"},
             %{x: ^title2, y: "literal", z: "otherliteral"}
           ] = Repo.all(query)
  end

  test "dynamic fields", %{archived_at: archived_at} do
    fields = [:archived_at]

    query = from(l in List, as: :list, select: ^fields)

    assert Query.to_sql(Repo, query) =~ """
           SELECT l0."archived_at" FROM \
           """

    assert [%{archived_at: ^archived_at}, %{title: nil}] = Repo.all(query)
  end

  test "static field", %{archived_at: archived_at} do
    static = from(l in List, as: :list, select: %{title: l.archived_at})

    assert Query.to_sql(Repo, static) =~ """
           SELECT l0."archived_at" FROM \
           """

    assert [%{title: ^archived_at}, %{title: nil}] = Repo.all(static)
  end

  test "dynamic field", %{archived_at: archived_at} do
    as = :list
    field = :archived_at

    ref = dynamic(field(as(^as), ^field))
    query = from(l in List, as: :list, select: ^%{title: ref})
    # assert query.select.take == static.select.take

    assert Query.to_sql(Repo, query) =~ """
           SELECT l0."archived_at" FROM \
           """

    assert [%{title: ^archived_at}, %{title: nil}] = Repo.all(query)
  end

  test "fixed field in interpolation" do
    query = from(l in List, as: :list, select: ^%{title: 3})
    query2 = from(l in List, as: :list, select: %{title: 3})
    assert query.select.expr == query2.select.expr
    assert query.select.params == query2.select.params

    assert [%{title: 3}, %{title: 3}] = Repo.all(query)
  end

  # test "static fragment", %{archived_at: archived_at} do
  #   static =
  #     from(l in List,
  #       as: :list,
  #       select: %{
  #         title: l.archived_at,
  #         template_name:
  #           fragment(
  #             "CASE WHEN ? THEN ? ELSE ? END",
  #             is_nil(l.from_template_id),
  #             "",
  #             "template_name"
  #           )
  #       },
  #       order_by: [asc: :id]
  #     )

  #   assert [
  #            %{title: ^archived_at, template_name: ""},
  #            %{title: nil, template_name: "template_name"}
  #          ] = Repo.all(static)
  # end

  test "dynamic fragment", %{archived_at: archived_at} do
    ref0 = dynamic(field(as(:list), :archived_at))

    ref =
      dynamic(
        [l],
        fragment(
          "CASE WHEN ? THEN ? ELSE ? END",
          is_nil(l.from_template_id),
          "",
          "template_name"
        )
      )

    query =
      from(l in List, as: :list, select: ^%{title: ref0, template_name: ref}, order_by: [asc: :id])

    assert [
             %{title: ^archived_at, template_name: ""},
             %{title: nil, template_name: "template_name"}
           ] = Repo.all(query)
  end

  test "dynamic fragment and static field", %{archived_at: archived_at} do
    ref =
      dynamic(
        [l],
        fragment(
          "CASE WHEN ? THEN ? ELSE ? END",
          is_nil(l.from_template_id),
          "",
          "template_name"
        )
      )

    query =
      from(l in List,
        as: :list,
        select: %{title: l.archived_at},
        select_merge: ^%{template_name: ref},
        order_by: [asc: :id]
      )

    # assert Query.to_sql(Repo, query) =~ """
    #        FROM "lists" AS l0 WHERE (exists((SELECT \
    #        """

    assert [
             %{title: ^archived_at, template_name: ""},
             %{title: nil, template_name: "template_name"}
           ] = Repo.all(query)
  end

  test "merges dynamic fragment into struct", %{archived_at: archived_at} do
    ref =
      dynamic(
        [l],
        fragment(
          "CASE WHEN ? THEN ? ELSE ? END",
          is_nil(l.from_template_id),
          "",
          "template_name"
        )
      )

    query =
      from(l in List,
        as: :list,
        select: [:title, :archived_at],
        select_merge: ^%{title: ref},
        order_by: [asc: :id]
      )

    # assert Query.to_sql(Repo, query) =~ """
    #        FROM "lists" AS l0 WHERE (exists((SELECT \
    #        """

    assert [
             %{title: "", archived_at: ^archived_at},
             %{title: "template_name", archived_at: nil}
           ] = Repo.all(query)
  end

  # test "merges dynamic fragment and static field", %{archived_at: archived_at} do
  #   ref =
  #     dynamic(
  #       [l],
  #       fragment(
  #         "CASE WHEN ? THEN ? ELSE ? END",
  #         is_nil(l.from_template_id),
  #         "",
  #         "template_name"
  #       )
  #     )

  #   query =
  #     from(l in List,
  #       as: :list,
  #       select: merge(%{title: l.archived_at}, ^%{template_name: ref}),
  #       order_by: [asc: :id]
  #     )

  #   # assert Query.to_sql(Repo, query) =~ """
  #   #        FROM "lists" AS l0 WHERE (exists((SELECT \
  #   #        """

  #   assert [
  #            %{title: ^archived_at, template_name: ""},
  #            %{title: nil, template_name: "template_name"}
  #          ] = Repo.all(query)
  # end

  test "dynamic where with subquery" do
    subquery =
      from(t in ListTemplate,
        where: parent_as(^:list).from_template_id == t.id,
        select: %{title: t.title}
      )

    where = dynamic([l], subquery(subquery) == l.title)
    query = from(l in List, as: :list, where: ^where)

    assert [%{title: "FANCY TEMPLATE"}] = Repo.all(query)
  end

  test "dynamic fragment with subquery" do
    subquery =
      from(t in ListTemplate,
        where: parent_as(^:list).from_template_id == t.id,
        select: %{title: t.title}
      )

    ref =
      dynamic(
        [l],
        fragment(
          "CASE WHEN ? THEN ? ELSE ? END",
          is_nil(l.from_template_id),
          "",
          subquery(subquery)
        )
      )

    query = from(l in List, as: :list, select: ^%{template_name: ref}, order_by: [asc: :id])

    assert [
             %{template_name: ""},
             %{template_name: "FANCY TEMPLATE"}
           ] = Repo.all(query)
  end

  test "dynamic fragment with subquery and field", %{archived_at: archived_at} do
    subquery =
      from(t in ListTemplate,
        where: parent_as(^:list).from_template_id == t.id,
        select: %{title: t.title}
      )

    ref =
      dynamic(
        [l],
        fragment(
          "CASE WHEN ? THEN ? ELSE ? END",
          is_nil(l.from_template_id),
          "",
          subquery(subquery)
        )
      )

    query =
      from(l in List,
        as: :list,
        select: %{title: l.archived_at},
        select_merge: ^%{template_name: ref},
        order_by: [asc: :id]
      )

    assert [
             %{title: ^archived_at, template_name: ""},
             %{title: nil, template_name: "FANCY TEMPLATE"}
           ] = Repo.all(query)
  end

  test "dynamic fragment with multiple subqueries and field", %{
    list: list,
    archived_at: archived_at,
    tasks: tasks
  } do
    created_by_id = list.created_by_id

    subquery0 =
      from(t in Task,
        where: t.list_id == parent_as(:list).id and t.created_by_id == ^created_by_id,
        select: max(t.due_on)
      )

    subquery1 =
      from(t in ListTemplate, where: parent_as(^:list).from_template_id == t.id, select: t.title)

    subquery2 = from(u in User, where: parent_as(^:list).created_by_id == u.id, select: u.email)

    ref =
      dynamic(
        [l],
        fragment(
          "CASE WHEN ? THEN ? ELSE ? END",
          is_nil(l.from_template_id),
          "",
          subquery(subquery1)
        )
      )

    query =
      from(l in List,
        as: :list,
        select: %{
          title: l.archived_at,
          val0: 0,
          maxdue: subquery(subquery0),
          val1: true,
          user_email: subquery(subquery2),
          val2: nil
        },
        select_merge:
          ^%{
            # val3: 8,
            template_name: ref,
            val4: "gr8"
          },
        select_merge:
          ^%{
            # val5: 1.337,
            maxdue: nil,
            # val6: [1, 2, 3],
            user_email: subquery(subquery1),
            # val3: 16
          },
        select_merge:
          ^%{
            user_email: subquery(subquery2),
            maxdue: subquery(subquery0)
          },
        order_by: [asc: :id]
      )

    max_due_on = tasks |> Enum.map(& &1.due_on) |> Enum.max(Date)

    assert [
             %{
               title: ^archived_at,
               maxdue: ^max_due_on,
               template_name: "",
               user_email: "alice@acme.org"
             },
             %{
               title: nil,
               maxdue: nil,
               template_name: "FANCY TEMPLATE",
               user_email: "alice@acme.org"
             }
           ] = Repo.all(query)
  end

  # test "where with subquery", %{list: list, archived_at: archived_at} do
  #   created_by_id = list.created_by_id
  #   subquery = from(t in Task, where: t.list_id == parent_as(:list).id and t.created_by_id == ^created_by_id, select: max(t.due_on))
  #   static =
  #     from(l in List,
  #       as: :list,
  #       where: subquery(subquery) == fragment("?::date", l.archived_at)
  #     )

  #   assert Query.to_sql(Repo, static) =~ """
  #          FROM "lists" AS l0 WHERE (exists((SELECT \
  #          """

  #   assert [%{archived_at: ^archived_at}] = Repo.all(static)
  # end

  # test "where with exists", %{archived_at: archived_at} do
  #   # created_by_id = list.created_by_id
  #   # subquery = from(t in Task, where: t.list_id == parent_as(:list).id and t.created_by_id == ^created_by_id, select: max(t.due_on))
  #   static =
  #     from(l in List,
  #       as: :list,
  #       where: exists(from(t in Task, where: t.list_id == parent_as(:list).id))
  #     )

  #   assert Query.to_sql(Repo, static) =~ """
  #          FROM "lists" AS l0 WHERE (exists((SELECT \
  #          """

  #   assert [%{archived_at: ^archived_at}] = Repo.all(static)
  # end

  # test "where with subquery comparison", %{archived_at: archived_at, tasks: tasks} do
  #   # created_by_id = list.created_by_id
  #   # subquery = from(t in Task, where: t.list_id == parent_as(:list).id and t.created_by_id == ^created_by_id, select: max(t.due_on))
  #   subquery = from(t in Task, where: t.list_id == parent_as(:list).id, select: max(t.due_on))
  #   max_due_on = tasks |> Enum.map(& &1.due_on) |> Enum.max(Date)
  #   static = from(l in List, as: :list, where: subquery(subquery) == ^max_due_on)

  #   assert Query.to_sql(Repo, static) =~ """
  #          FROM "lists" AS l0 WHERE ((SELECT \
  #          """

  #   assert [%{archived_at: ^archived_at}] = Repo.all(static)
  # end

  # test "static exists", %{archived_at: archived_at} do
  #   static =
  #     from(l in List,
  #       as: :list,
  #       select: %{
  #         title: l.archived_at,
  #         hastasks: exists(from(t in Task, where: t.list_id == parent_as(:list).id))
  #       }
  #     )

  #   assert [
  #            %{title: ^archived_at, hastasks: true},
  #            %{title: nil, hastasks: false}
  #          ] = Repo.all(static)
  # end

  # test "static exists2", %{archived_at: archived_at} do
  #   subquery = from(t in Task, where: t.list_id == parent_as(:list).id)

  #   static =
  #     from(l in List, as: :list, select: %{title: l.archived_at, hastasks: exists(subquery)})

  #   assert [
  #            %{title: ^archived_at, hastasks: true},
  #            %{title: nil, hastasks: false}
  #          ] = Repo.all(static)
  # end

  # test "static subquery", %{list: list, archived_at: archived_at, tasks: tasks} do
  #   created_by_id = list.created_by_id

  #   subquery =
  #     from(t in Task,
  #       where: t.list_id == parent_as(:list).id and t.created_by_id == ^created_by_id,
  #       select: max(t.due_on)
  #     )

  #   static =
  #     from(l in List, as: :list, select: %{title: l.archived_at, maxdue: subquery(subquery)})

  #   max_due_on = tasks |> Enum.map(& &1.due_on) |> Enum.max(Date)

  #   assert [
  #            %{title: ^archived_at, maxdue: ^max_due_on},
  #            %{title: nil, maxdue: nil}
  #          ] = Repo.all(static)
  # end

  # # test "raises on non-simple subquery comparison", %{list: list, archived_at: archived_at, tasks: tasks} do
  # #   # created_by_id = list.created_by_id
  # #   # subquery = from(t in Task, where: t.list_id == parent_as(:list).id and t.created_by_id == ^created_by_id, select: max(t.due_on))
  # #   subquery = from(t in Task, where: t.list_id == parent_as(:list).id, select: %{due_on: max(t.due_on), due_min: min(t.due_on)})
  # #   max_due_on = tasks |> Enum.map(& &1.due_on) |> Enum.max(Date)
  # #   static = from(l in List, as: :list, where: subquery(subquery) == ^max_due_on)

  # #   assert_raise ArgumentError, fn ->
  # #     Repo.all(static)
  # #   end
  # # end

  # # test "raises on non-simple select of subquery used in select", %{list: list, archived_at: archived_at, tasks: tasks} do
  # #   subquery1 = from(t in ListTemplate, where: parent_as(^:list).from_template_id == t.id, select: %{title: t.title})
  # #   ref = dynamic([l], fragment(
  # #     "CASE WHEN ? THEN ? ELSE ? END",
  # #     is_nil(l.from_template_id),
  # #     "",
  # #     subquery(subquery1)
  # #   ))
  # #   query = from(l in List, as: :list, select: %{title: l.archived_at, template_name: ^ref}, order_by: [asc: :id])

  # #   assert_raise ArgumentError, fn ->
  # #     Repo.all(query)
  # #   end
  # # end
end
