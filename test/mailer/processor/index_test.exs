defmodule Test.Rivet.Mailer.Processor.IndexTest do
  use Test.Support.Mailer.Case.Mailer
  use Rivet.Mailer
  import ExUnit.CaptureLog

  # none
  # doctest Rivet.Mailer.Processor, import: true

  test "Processor" do
    # mailer = Application.get_env(:rivet_email, :mailer)
    # enabled = Application.get_env(:rivet_email, :enabled)
    # Application.put_env(:rivet_email, :mailer, Mock.Mailer.Dispatchto)
    # Application.put_env(:rivet_email, :enabled, true)
    Processor.enabled(true)

    on_exit(fn ->
      # Application.put_env(:rivet_email, :mailer, mailer)
      # Application.put_env(:rivet_email, :enabled, enabled)
      Processor.enabled(false)
    end)

    s = insert_good_mailer_dispatch()
    last = Rivet.Utils.Time.now() - 10
    state = %{last: last, ref: nil}

    assert {:ok, %{sent_at: nil, lock: nil}} = Dispatch.one(id: s.id)

    # run it first with one in queue
    assert {:noreply, %{last: updated}} = Processor.handle_info(:process_queue, state)
    assert last != updated

    assert {:ok, %{sent_at: d, lock: nil}} = Dispatch.one(id: s.id)
    assert not is_nil(d)

    # do it a second time to run without any in queue
    assert {:noreply, %{last: _}} = Processor.handle_info(:process_queue, state)
    assert {:ok, %{sent_at: d}} = Dispatch.one(id: s.id)
    assert not is_nil(d)
  end
end
