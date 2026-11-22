defmodule Rivet.Mailer.Test.Dispatch.LogTest do
  use Rivet.Mailer.Test.Case, async: true
  use Rivet.Mailer
  alias Dispatch.Log

  test "model tests" do
    assert %Log{id: id} = insert(:mailer_dispatch_log)
    assert is_uuid(id)
    assert %Log{id: ^id} = Log.one!(id: id)
    params = params_with_assocs(:mailer_dispatch_log)
    assert {:ok, %Log{} = d} = Log.create(params)
    assert {:ok, _} = Log.delete(d)
  end

  test "add" do
    assert {:error, :not_found} = Log.add(:ses, :bad, {:ses, "nope"}, %{type: "x", log: "y"})

    # # insert good, verify email status changed
    %{id: d_id} = insert(:mailer_dispatch, status: :pending, sender_id: "ses:someid")

    assert {:ok, ^d_id} =
             Log.add(:ses, :aborted, {:dispatch_id, d_id}, %{type: :bouncing, log: %{reason: "x"}})

    %{status: :aborted} = Dispatch.one!(d_id)

    # update bad status & type
    log =
      ExUnit.CaptureLog.capture_log(fn ->
        assert {:ok, ^d_id} =
                 Log.add(:ses, :bogus, {:ses, "someid"}, %{type: :bogus, log: %{reason: "x"}})
      end)

    assert log =~ ~r/Unable to update Mailer.Dispatch: status is invalid/
    assert log =~ ~r/Unable to save Mailer.Dispatch.Log/
  end
end
