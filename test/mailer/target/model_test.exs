defmodule Test.Mailer.Target.ModelTest do
  use Test.Support.Mailer.Case, async: true
  use Rivet.Mailer

  test "model tests" do
    assert %Target{email, id: id} = insert(:mailer_target)
    assert is_uuid(id)
    assert %Target{id: ^id} = Target.one!(id: id)
    params = params_with_assocs(:mailer_target)
    assert {:ok, %Target{} = d} = Target.create(params)
    assert {:ok, _} = Target.delete(d)

    assert {:ok, ^id} = Target.upsert_email(email)
    assert {:ok, id2} = Target.upsert_email(%@email_model{address: email.address})
    # we allow multiples of the same address when its not tied to an email_id
    assert id2 != id
  end
end
