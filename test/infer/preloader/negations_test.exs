defmodule Infer.Preloader.NegationsTest do
  use Infer.Test.DataCase

  defmodule ListRules do
    use Infer.Rules, for: List

    infer has_template_1?: true, when: {:not, %{from_template: nil}}
    infer has_template_1?: false

    infer has_template_2?: true, when: %{from_template: {:not, nil}}
    infer has_template_2?: false

    infer has_no_verified_template_1?: true, when: {:not, %{from_template: %{verified: true}}}
    infer has_no_verified_template_1?: false

    infer negated_preload_required: true, when: {:not, %{from_template: %{verified: true}}}
    infer negated_preload_required: false

    infer preloads_via_nested_predicate?: true, when: %{negated_preload_required: true}
    infer preloads_via_nested_predicate?: false

    infer negated_preloads_via_nested_predicate?: true,
          when: {:not, %{negated_preload_required: true}}

    infer negated_preloads_via_nested_predicate?: false
  end

  describe "preloads when using" do
    setup do
      template = create(ListTemplate)
      list = create(List, %{from_template_id: template.id, created_by: %{}})

      assert %Ecto.Association.NotLoaded{} = list.from_template

      [list: list, template: template]
    end

    test "when: {:not, %{from_template: nil}}", %{list: list, template: template} do
      list =
        list
        |> Infer.preload(:has_template_1?, extra_rules: ListRules)

      template_id = template.id
      assert %ListTemplate{id: ^template_id} = list.from_template
    end

    test "when: %{from_template: {:not, nil}}", %{list: list, template: template} do
      list =
        list
        |> Infer.preload(:has_template_2?, extra_rules: ListRules)

      template_id = template.id
      assert %ListTemplate{id: ^template_id} = list.from_template
    end

    test "when: {:not, %{from_template: %{verified: true}}}", %{list: list, template: template} do
      list =
        list
        |> Infer.preload(:has_no_verified_template_1?, extra_rules: ListRules)

      template_id = template.id
      assert %ListTemplate{id: ^template_id} = list.from_template
    end

    test "preloads_via_nested_predicate - negated child predicate requires preload", %{
      list: list,
      template: template
    } do
      list =
        list
        |> Infer.preload(:preloads_via_nested_predicate?, extra_rules: ListRules)

      template_id = template.id
      assert %ListTemplate{id: ^template_id} = list.from_template
    end

    test "negated_preloads_via_nested_predicate - negated predicate uses negated child prediate that requires preload",
         %{
           list: list,
           template: template
         } do
      list =
        list
        |> Infer.preload(:negated_preloads_via_nested_predicate?,
          extra_rules: ListRules
        )

      template_id = template.id
      assert %ListTemplate{id: ^template_id} = list.from_template
    end
  end
end
