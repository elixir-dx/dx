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

    test "emits compiler warning when called directly" do
      assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
               bool_constant()
             end) =~ "Use Dx.load as entrypoint"
    end
  end
end
