defmodule Dx.DefdTest do
  use ExUnit.Case, async: true

  import Dx.Defd

  describe "constants" do
    defd bool_constant() do
      true
    end

    test "returns true" do
      assert Dx.Defd.load(bool_constant()) == {:ok, true}
    end
  end
end
