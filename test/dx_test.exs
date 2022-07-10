defmodule DxTest do
  use Dx.Test.DataCase

  test "setup works" do
    user = create(User, %{email: "sia@vu.net", first_name: "Sia", last_name: "Vu"})

    assert user |> Dx.get!(:full_name) == "SiaVu"
  end
end
