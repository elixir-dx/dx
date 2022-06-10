defmodule Infer.Preloader.AssociationExistsDoesNotExistTest do
  use Infer.Test.DataCase

  defmodule Rules do
    use Infer.Rules, for: List

    infer has_template_1?: false, when: %{from_template: nil}
    infer has_template_1?: true

    infer has_template_2?: true, when: %{from_template: {:not, nil}}
    infer has_template_2?: false

    infer has_template_3?: true, when: {:not, %{from_template: nil}}
    infer has_template_3?: false

    infer has_template_id_1?: false, when: %{from_template_id: nil}
    infer has_template_id_1?: true

    infer has_template_id_2?: true, when: %{from_template_id: {:not, nil}}
    infer has_template_id_2?: false

    infer has_template_id_3?: true, when: {:not, %{from_template_id: nil}}
    infer has_template_id_3?: false

    infer references_template_in_ref?: true,
          when: %{hourly_points: {:ref, [:from_template, :hourly_points]}}

    infer references_template_in_ref?: false
  end

  describe "association does not exist" do
    setup do
      list = create(List, %{created_by: %{}})
      refute list.from_template_id

      [list: list]
    end

    test "and is not preloaded - has_template_1", %{list: list} do
      assert_raise(Infer.Error.NotLoaded, fn ->
        Repo.get!(List, list.id)
        |> Infer.get!(:has_template_1?, extra_rules: Rules) == false
      end)
    end

    test "and is not preloaded - has_template_2", %{list: list} do
      assert_raise(Infer.Error.NotLoaded, fn ->
        Repo.get!(List, list.id)
        |> Infer.get!(:has_template_2?, extra_rules: Rules) == false
      end)
    end

    test "and is not preloaded - has_template_3", %{list: list} do
      assert_raise(Infer.Error.NotLoaded, fn ->
        Repo.get!(List, list.id)
        |> Infer.get!(:has_template_3?, extra_rules: Rules) == false
      end)
    end

    test "and is not preloaded - has_template_id_1", %{list: list} do
      assert Repo.get!(List, list.id)
             |> Infer.get!(:has_template_id_1?, extra_rules: Rules) == false
    end

    test "and is not preloaded - has_template_id_2", %{list: list} do
      assert Repo.get!(List, list.id)
             |> Infer.get!(:has_template_id_2?, extra_rules: Rules) == false
    end

    test "and is not preloaded - has_template_id_3", %{list: list} do
      assert Repo.get!(List, list.id)
             |> Infer.get!(:has_template_id_3?, extra_rules: Rules) == false
    end

    test "and is not preloaded - references_template_in_ref", %{list: list} do
      assert_raise(Infer.Error.NotLoaded, fn ->
        assert Repo.get!(List, list.id)
               |> Infer.get!(:references_template_in_ref?, extra_rules: Rules) == false
      end)
    end

    test "and is preloaded - has_template_1", %{list: list} do
      assert list
             |> Infer.preload(:has_template_1?, extra_rules: Rules)
             |> Infer.get!(:has_template_1?, extra_rules: Rules) == false
    end

    test "and is preloaded - has_template_2", %{list: list} do
      assert list
             |> Infer.preload(:has_template_2?, extra_rules: Rules)
             |> Infer.get!(:has_template_2?, extra_rules: Rules) == false
    end

    test "and is preloaded - has_template_3", %{list: list} do
      assert list
             |> Infer.preload(:has_template_3?, extra_rules: Rules)
             |> Infer.get!(:has_template_3?, extra_rules: Rules) == false
    end

    test "and is preloaded - has_template_id_1", %{list: list} do
      assert list
             |> Infer.get!(:has_template_id_1?, extra_rules: Rules) == false
    end

    test "and is preloaded - has_template_id_2", %{list: list} do
      assert Repo.get!(List, list.id)
             |> Infer.get!(:has_template_id_2?, extra_rules: Rules) == false
    end

    test "and is preloaded - has_template_id_3", %{list: list} do
      assert list
             |> Infer.get!(:has_template_id_3?, extra_rules: Rules) == false
    end

    @tag :skip
    test "and is preloaded - references_template_in_ref", %{list: list} do
      assert list
             |> Infer.preload(:references_template_in_ref?, extra_rules: Rules)
             |> Infer.get!(:references_template_in_ref?, extra_rules: Rules, debug: :trace) ==
               false
    end
  end

  describe "association exists" do
    setup do
      template = create(ListTemplate)

      list = create(List, %{from_template_id: template.id, created_by: %{}})

      assert list.from_template_id
      assert %Ecto.Association.NotLoaded{} = list.from_template

      [list: list]
    end

    test "and is not preloaded - has_template_1", %{list: list} do
      assert_raise(Infer.Error.NotLoaded, fn ->
        assert Repo.get!(List, list.id)
               |> Infer.get!(:has_template_1?, extra_rules: Rules)
      end)
    end

    test "and is not preloaded - has_template_2", %{list: list} do
      assert_raise(Infer.Error.NotLoaded, fn ->
        assert Repo.get!(List, list.id)
               |> Infer.get!(:has_template_2?, extra_rules: Rules)
      end)
    end

    test "and is not preloaded - has_template_3", %{list: list} do
      assert_raise(Infer.Error.NotLoaded, fn ->
        assert Repo.get!(List, list.id)
               |> Infer.get!(:has_template_3?, extra_rules: Rules)
      end)
    end

    test "and is not preloaded - has_template_id_1", %{list: list} do
      assert list
             |> Infer.get!(:has_template_id_1?, extra_rules: Rules)
    end

    test "and is not preloaded - has_template_id_2", %{list: list} do
      assert list
             |> Infer.get!(:has_template_id_2?, extra_rules: Rules)
    end

    test "and is not preloaded - has_template_id_3", %{list: list} do
      assert list
             |> Infer.preload(:has_template_id_3?, extra_rules: Rules)
             |> Infer.get!(:has_template_id_3?, extra_rules: Rules)
    end

    test "and is not preloaded - references_template_in_ref", %{list: list} do
      assert_raise(Infer.Error.NotLoaded, fn ->
        assert list
               |> Infer.get!(:references_template_in_ref?, extra_rules: Rules)
      end)
    end

    test "and is preloaded - has_template_1", %{list: list} do
      assert list
             |> Infer.preload(:has_template_1?, extra_rules: Rules)
             |> Infer.get!(:has_template_1?, extra_rules: Rules)
    end

    test "and is preloaded - has_template_2", %{list: list} do
      assert list
             |> Infer.preload(:has_template_2?, extra_rules: Rules)
             |> Infer.get!(:has_template_2?, extra_rules: Rules)
    end

    test "and is preloaded - has_template_3", %{list: list} do
      assert list
             |> Infer.preload(:has_template_3?, extra_rules: Rules)
             |> Infer.get!(:has_template_3?, extra_rules: Rules)
    end

    test "and is preloaded - has_template_id_1", %{list: list} do
      assert list
             |> Infer.get!(:has_template_id_1?, extra_rules: Rules)
    end

    test "and is preloaded - has_template_id_2", %{list: list} do
      assert list
             |> Infer.get!(:has_template_id_2?, extra_rules: Rules)
    end

    test "and is preloaded - has_template_id_3", %{list: list} do
      assert list
             |> Infer.get!(:has_template_id_3?, extra_rules: Rules)
    end

    @tag :skip
    test "and is preloaded - references_template_in_ref", %{list: list} do
      assert list
             |> Infer.preload(:references_template_in_ref?, extra_rules: Rules)
             |> Infer.get!(:references_template_in_ref?, extra_rules: Rules)
    end
  end
end
