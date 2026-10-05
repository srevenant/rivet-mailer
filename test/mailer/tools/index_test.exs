defmodule Test.Mailer.Utils.IndexTest do
  use Test.Support.Mailer.Case
  use Rivet.Mailer
  import Rivet.Mailer.Tools.Email, only: [get_best_email: 1]

  doctest Rivet.Mailer.Tools.Email, import: true
  doctest Rivet.Mailer.Tools.Format, import: true

  test "get_best_email" do
    assert %{user, id: e_id} = insert(:ident_email, verified: true)
    assert {:ok, %@email_model{id: ^e_id}} = get_best_email(user)

    ExUnit.CaptureLog.capture_log(fn ->
      assert {:error, "Cannot find email for user"} = get_best_email(insert(:ident_user))
    end)
  end
end
