defmodule Test.Mailer.Sub.ModelTest do
  use Test.Support.Mailer.Case, async: true
  alias Rivet.Mailer.Sub

  test "model tests" do
    assert %Sub{id} = insert(:mailer_sub)
    assert is_uuid(id)
    assert %Sub{id: ^id} = Sub.one!(id: id)
    params = params_with_assocs(:mailer_sub)
    assert {:ok, %Sub{} = d} = Sub.create(params)
    assert {:ok, _} = Sub.delete(d)
  end
end
