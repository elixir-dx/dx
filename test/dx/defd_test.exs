defmodule Dx.DefdTest do
  use ExUnit.Case, async: true

  import Dx.Defd

  describe "constants" do
    defd bool_constant() do
      true
    end

    test "returns true" do
      assert load(bool_constant()) == {:ok, true}
    end

    test "emits compiler warning when called directly" do
      assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
               bool_constant()
             end) =~ "Use Dx.load as entrypoint"
    end
  end

  describe "simple arg" do
    defd simple_arg(arg) do
      arg
    end

    test "returns arg" do
      assert load(simple_arg(1)) == {:ok, 1}
    end
  end
end
