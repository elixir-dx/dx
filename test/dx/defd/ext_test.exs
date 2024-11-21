defmodule Dx.Defd.ExtTest do
  use ExUnit.Case, async: true

  alias Dx.Defd.Ext.ArgInfo
  alias Dx.Defd.Ext.FunInfo

  doctest FunInfo, import: true
end
