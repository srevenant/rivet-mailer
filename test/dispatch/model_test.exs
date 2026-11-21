defmodule Rivet.Mailer.Test.Dispatch.ModelTest do
  use Rivet.Mailer.Test.Case, async: true
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

  test "coverage for default for queue/4" do
    e = insert(:ident_email)
    lock = Ecto.UUID.generate()
    assert {:ok, %{lock: ^lock}} = Dispatch.queue(e, CriticalFail, %{}, %{lock})
    assert {:ok, %{lock: nil}} = Dispatch.queue(e, CriticalFail, %{})
  end
end
