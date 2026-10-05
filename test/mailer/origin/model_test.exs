defmodule Test.Mailer.Origin.ModelTest do
  use Test.Support.Mailer.Case, async: true
  alias Rivet.Mailer.Origin

  test "model tests" do
    assert %Origin{user, id: id} = insert(:mailer_origin)
    assert is_uuid(id)
    assert %Origin{id: ^id} = Origin.one!(id: id)
    params = params_with_assocs(:mailer_origin)
    assert {:ok, %Origin{} = d} = Origin.create(params)
    assert {:ok, _} = Origin.delete(d)
    assert {:ok, ^id} = Origin.upsert_origin(user)
  end

  # test "upsert_origin" do
  #   insert(:user)
  # end
end
