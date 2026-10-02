defmodule Test.Mailer.Processor.IndexTest do
  use Test.Support.Mailer.Case
  use Rivet.Mailer
  import ExUnit.CaptureLog

  test "Processor" do
    Processor.enabled(true)

    on_exit(fn -> Processor.enabled(false) end)

    s = insert_good_mailer_dispatch()
    last = Rivet.Utils.Time.now() - 10
    state = %{last: last, ref: nil}

    assert {:ok, %{sent_at: nil, lock: nil, status: :pending}} = Dispatch.one(id: s.id)

    # run it first with one in queue
    assert {:noreply, %{last: updated}} = Processor.handle_info(:process_queue, state)
    assert last != updated

    assert {:ok, %{sent_at, lock: nil}} = Dispatch.one(id: s.id)
    assert not is_nil(sent_at)

    # do it a second time to run without any in queue
    assert {:noreply, %{last: _}} = Processor.handle_info(:process_queue, state)
    assert {:ok, %{sent_at: d}} = Dispatch.one(id: s.id)
    assert not is_nil(d)
  end
end
