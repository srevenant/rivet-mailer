defmodule Test.Mailer.Target.ModelTest do
  use Test.Support.Mailer.Case, async: true
  alias Rivet.Mailer.Target

  test "model tests" do
    assert %Target{email, id: id} = insert(:mailer_target)
    assert is_uuid(id)
    assert %Target{id: ^id} = Target.one!(id: id)
    params = params_with_assocs(:mailer_target)
    assert {:ok, %Target{} = d} = Target.create(params)
    assert {:ok, _} = Target.delete(d)

    assert {:ok, ^id} = Target.upsert_email(email)
  end
end
