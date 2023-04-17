defmodule Dx.ResultTest do
  use ExUnit.Case, async: true

  doctest Dx.Result

  test "re-raises exception as is" do
    assert_raise(ArgumentError, fn ->
      Dx.Result.unwrap!({:error, %ArgumentError{}})
    end)
  end

  test "raises :timeout as Dx.Error.Timeout" do
    assert_raise(Dx.Error.Timeout, fn ->
      Dx.Result.unwrap!({:error, :timeout})
    end)
  end

  test "raises other non-exceptions as Dx.Error.Generic" do
    assert_raise(Dx.Error.Generic, fn ->
      Dx.Result.unwrap!({:error, :not_an_exception})
    end)
  end
end
