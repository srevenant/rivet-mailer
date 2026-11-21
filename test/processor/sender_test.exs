defmodule Rivet.Mailer.Test.Processor.SenderTest do
  use Rivet.Mailer.Test.Case
  use Rivet.Mailer
  import ExUnit.CaptureLog
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

    assert capture_log(fn ->
             assert {:ok, _} = Sender.send(d)
           end) =~ ~r/email dispatched/

    assert %{sender_id: "ses:ses-test-id"} = is_dispatched(d.id)
  end

  test "Template error aborts dispatch" do
    Rivet.Ident.Test.Fixtures.NullTemplate.listen()

    d = good_dispatch(%{error: "other"})

    assert capture_log(fn -> assert {:ok, _} = Sender.send(d) end) =~
             ~r/Mailer abort: error sending email.*message=\"Woops Error/

    assert {:ok, %{status: :aborted, lock: nil, sent_at: nil}} = Dispatch.one(id: d.id)

    assert {:ok, %{type: :aborted}} = Dispatch.Log.one(dispatch_id: d.id, type: :aborted)

    assert_receive {:report_, {message, opts}}
    assert message =~ "Mailer abort: error sending email"
    assert opts[:dispatch_id] == d.id
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

    assert capture_log(fn ->
             assert {:aborted, "Mailer DISABLED: unexpected result shape", response: :wat} =
                      Sender.normalize_result(:wat)
           end) =~ ~r/DISABLED due to unexpected result/

    assert {:aborted, "wat", []} = Sender.normalize_result({:error, :wat, []})
  end

  test "CriticalFail abort does not trigger another report" do
    Rivet.Ident.Test.Fixtures.NullTemplate.listen()

    d =
      insert(:mailer_dispatch, target: insert_good_target(), template: CriticalFail)
      |> Ecto.reset_fields([:target])

    assert capture_log(fn ->
             assert {:ok, %Dispatch{status: :aborted}} = Mailer.Processor.Sender.send(d)
           end) =~ "Mailer abort: error sending email (CriticalFail notification)"

    refute_receive {:report_, _}, 50

    assert {:ok, %Dispatch{status: :aborted}} = Dispatch.one(d.id)
  end

  test "create_dispatch preloads and locks CriticalFail" do
    assert {:ok, %Dispatch{target: %Target{}, lock: lock, locked_at: %DateTime{}} = d} =
             CriticalFail.create_dispatch(:errors, %{log: "test", info: []})

    assert is_binary(lock)
    assert {:ok, %Dispatch{lock: ^lock}} = Dispatch.one(d.id)
  end
end
