defmodule Dx.Engine.ExtraRulesTest do
  use Dx.Test.DataCase

  test "extra_rules module that does not exist raises error" do
    assert_raise(
      Dx.Error.RulesNotFound,
      "Module NonExistingRules is not compiled, error: :nofile",
      fn ->
        Dx.get(%User{}, :something, extra_rules: NonExistingRules)
      end
    )
  end

  test "extra_rules module without rules raises error" do
    assert_raise(
      Dx.Error.RulesNotFound,
      "Module Dx.Engine.ExtraRulesTest does not define any rules",
      fn ->
        Dx.get(%User{}, :something, extra_rules: __MODULE__)
      end
    )
  end
end
