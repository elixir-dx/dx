defmodule Dx.TimeoutTest do
  use Dx.Test.DataLoadingCase

  defmodule ExtraRules do
    use Dx.Rules, for: Role
    infer cause_timeout: {:query_one, Role, [name: "Role"], sleep: 9_999}
  end

  setup do
    [role: create(Role, %{name: "Role"})]
  end

  describe "timeout" do
    # Currently failing
    test "raises Dx.Error.Timeout when ecto repo timeout is exceeded", %{role: role} do
      loader_options = [repo_options: [timeout: 100], timeout: 999]

      assert_raise Dx.Error.Timeout, fn ->
        Dx.load!(role, :cause_timeout, extra_rules: ExtraRules, loader_options: loader_options)
      end
    end

    test "raises Dx.Error.Timeout when dataloader timeout is exceeded", %{role: role} do
      loader_options = [timeout: 100, repo_options: [timeout: 999]]

      assert_raise Dx.Error.Timeout, fn ->
        Dx.load!(role, :cause_timeout, extra_rules: ExtraRules, loader_options: loader_options)
      end
    end
  end
end
