defmodule Test.Mailer.Utils.IndexTest do
  use Test.Support.Mailer.Case
  import Rivet.Mailer.Utils.Email, only: [get_best_email: 1]

  doctest Rivet.Mailer.Utils.Email, import: true
  doctest Rivet.Mailer.Utils.Format, import: true

  test "get_best_email" do
    assert %{user, id: e_id} = insert(:ident_email, verified: true)
    assert {:ok, %Rivet.Ident.Email{id: ^e_id}} = get_best_email(user)

    ExUnit.CaptureLog.capture_log(fn ->
      assert {:error, "Cannot find email for user"} = get_best_email(insert(:ident_user))
    end)
  end
end
