defmodule Rivet.Mailer.Test.Tools.CodeTest do
  use Rivet.Mailer.Test.Case
  alias Rivet.Mailer.Tools.Code

  # use Rivet.Mailer
  # import Rivet.Mailer.Tools.Email, only: [get_best_email: 1]
  #
  # doctest Rivet.Mailer.Tools.Email, import: true
  # doctest Rivet.Mailer.Tools.Format, import: true
  #
  # test "get_best_email" do
  #   assert %{user, id: e_id} = insert(:ident_email, verified: true)
  #   assert {:ok, %@email_model{id: ^e_id}} = get_best_email(user)
  #
  #   ExUnit.CaptureLog.capture_log(fn ->
  #     assert {:error, "Cannot find email for user"} = get_best_email(insert(:ident_user))
  #   end)
  # end

  test "various" do
    d = %{target: %{user}} = insert(:mailer_dispatch)
    assert {:ok, %{code_id}} = Code.enrich_with_code(user.id, :password)
    assert code_id > 0

    assert {:ok, %{assigns: %{code}}} =
             Code.code_enrich_assigns(%{d | assigns: Map.put(d.assigns, :code_id, code_id)})

    assert not_empty_str(code)
  end
end
