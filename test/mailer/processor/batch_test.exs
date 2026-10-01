defmodule Test.Rivet.Mailer.Processor.BatchTest do
  use Test.Support.Mailer.Case.Mailer
  import ExUnit.CaptureLog

  setup do
    Processor.enabled(true)
    :ok
  end

  defp good_dispatch(assigns \\ %{}) do
    # assert is just to assure its the right shape
    assert %{status: :pending, lock: nil} = insert_good_mailer_dispatch(assigns)
  end

  defp assert_stranded(dispatch_id) do
    assert {:ok, %{sent_at, lock, status: :pending}} = Dispatch.one(dispatch_id)
    assert is_uuid(lock)
    assert is_nil(sent_at)
  end

  test "Normal processing leaves nothing pending" do
    d = good_dispatch()

    log =
      capture_log(fn ->
        assert {:ok, [:ok]} = Processor.Batch.process(10, 1)
      end)

    assert log =~ ~r/Processing pending dispatches - count=1 pending=1/
    assert log =~ ~r/Mailer: email dispatched.*dispatch_id=#{d.id}/
    assert log =~ ~r/Mailer: Finished processing dispatches/

    assert {:ok, %{sent_at, status: :dispatched, lock: nil}} = Dispatch.one(id: d.id)

    refute is_nil(sent_at)
  end

  test "coverage - force a :none result" do
    assert {:ok, []} = Processor.Batch.process(10, 0)
  end

  test "Worker exit strands dispatch" do
    die = good_dispatch(%{error: "exit"})
    good = good_dispatch()

    assert capture_log(fn ->
             assert {:ok, batch} = Processor.Batch.process(10, 2)
             assert {:error, "Mailer abort: dispatch worker crashed"} in batch
             assert :ok in batch
           end) =~ ~r/Mailer abort: dispatch worker crashed/

    assert_stranded(die.id)
    assert {:ok, %{status: :dispatched}} = Dispatch.one(id: good.id)
  end

  test "Worker timeout strands dispatch" do
    d = good_dispatch(%{error: "timeout"})

    assert capture_log(fn ->
             assert {:ok, [error: "Mailer abort: dispatch worker timed out"]} =
                      Processor.Batch.process(10, 1)
           end) =~ ~r/Mailer abort: dispatch worker timed out/

    assert_stranded(d.id)
  end
end
