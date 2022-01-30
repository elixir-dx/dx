defmodule InferTest do
  use Infer.Test.DataCase

  test "setup works" do
    user = %User{email: "sia@vu.net", first_name: "Sia", last_name: "Vu"} |> Repo.insert!()

    assert user |> Infer.get!(:full_name) == "SiaVu"
  end
end
