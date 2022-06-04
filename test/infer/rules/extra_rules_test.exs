defmodule Infer.Engine.ExtraRulesTest do
  use Infer.Test.DataCase

  test "extra_rules module that does not exist raises error" do
    assert_raise(
      Infer.Error.RulesNotFound,
      "Module NonExistingRules is not compiled, error: :nofile",
      fn ->
        Infer.get(%User{}, :something, extra_rules: NonExistingRules)
      end
    )
  end

  test "extra_rules module without rules raises error" do
    assert_raise(
      Infer.Error.RulesNotFound,
      "Module Infer.Engine.ExtraRulesTest does not define any rules",
      fn ->
        Infer.get(%User{}, :something, extra_rules: __MODULE__)
      end
    )
  end
end
