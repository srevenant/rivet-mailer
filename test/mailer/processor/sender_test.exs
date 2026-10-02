defmodule Test.Mailer.Processor.SenderTest do
  use Test.Support.Mailer.Case
  use Rivet.Mailer
  alias Processor.Sender

  defp good_dispatch(assigns) do
    assert %{status: :pending, lock: nil} = insert_good_mailer_dispatch(assigns)
  end

  defp is_dispatched(dispatch_id) do
    assert {:ok, %{status: :dispatched, lock: nil} = result} = Dispatch.one(dispatch_id)
    result
  end

  test "Successful SES dispatch saves sender id" do
    d = good_dispatch(%{result: "ses"})
    assert {:ok, _} = Sender.send(d)
    assert %{sender_id: "ses:ses-test-id"} = is_dispatched(d.id)
  end

  test "Template error aborts dispatch" do
    d = good_dispatch(%{error: "other"})

    assert capture_log(fn -> assert {:ok, _} = Sender.send(d) end) =~
             ~r/Mailer abort: error sending email.*message=\"Woops Error/

    assert {:ok, %{status: :aborted, lock: nil, sent_at: nil}} = Dispatch.one(id: d.id)

    assert {:ok, %{type: :aborted}} = Dispatch.Log.one(dispatch_id: d.id, type: :aborted)
  end

  test "Template exception aborts dispatch" do
    d = good_dispatch(%{error: "traceback"})

    assert capture_log(fn -> assert {:ok, _} = Sender.send(d) end) =~
             ~r/Mailer abort: error sending email.*message=Traceback/

    assert {:ok, %{status: :aborted, lock: nil}} = Dispatch.one(id: d.id)
  end

  test "Map error aborts dispatch" do
    d = good_dispatch(%{error: "error-map"})

    assert capture_log(fn -> assert {:ok, _} = Sender.send(d) end) =~
             ~r/Mailer abort: error sending email/

    assert {:ok, %{status: :aborted, lock: nil}} = Dispatch.one(id: d.id)
  end

  test "normalize result edge cases" do
    assert {:aborted, "abort", []} = Sender.normalize_result({:abort, "abort"})
    assert {:aborted, "error", []} = Sender.normalize_result({:error, "error"})

    assert {:aborted, "uhoh: woops", [1]} =
             Sender.normalize_result({:error, %{code: "uhoh", message: "woops"}, [1]})

    assert {:aborted, "Mailer DISABLED: unexpected result shape", response: :wat} =
             Sender.normalize_result(:wat)
  end
end
