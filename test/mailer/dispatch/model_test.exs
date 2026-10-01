defmodule Test.Rivet.Mailer.DispatchTest do
  use Test.Support.Mailer.Case, async: true
  use Core.ContextClient
  alias Rivet.Mailer.Dispatch

  doctest Dispatch.Lib, import: true

  test "model tests" do
    assert %Dispatch{id: id} = insert(:mailer_dispatch)
    assert is_uuid(id)
    assert %Dispatch{id: ^id} = Dispatch.one!(id: id)
    params = params_with_assocs(:mailer_dispatch)
    assert {:ok, %Dispatch{} = d} = Dispatch.create(params)
    assert {:ok, _} = Dispatch.delete(d)
  end
end
