defmodule Rivet.Mailer.Test.Template.IndexTest do
  use Rivet.Mailer.Test.Case
  alias Rivet.Mailer.Template
  alias Rivet.Mailer.Dispatch

  doctest Mailer.Template, import: true

  alias Rivet.Mailer.Test.FunctionalTemplate

  test "FunctionalTemplate" do
    %{user} = insert(:ident_handle)
    e = insert(:ident_email, user: user)

    expect_queue(FunctionalTemplate, [user], ~r/had its password changed/)

    expect_queue(FunctionalTemplate, ["narf@ridersofthestars.com"], ~r/had its password changed/)

    assert {:error, "Address is not eligible for receiving email (status=bouncing)"} =
             Template.Queue.valid_target(%{e | status: :bouncing}, [])

    assert ExUnit.CaptureLog.capture_log(fn ->
             :ok = Template.Queue.valid_target(%{e | status: :bouncing}, force: true)
           end) =~ ~r/Overriding and sending to email address in status=bouncing/

    assert {:ok, [%Dispatch{}]} = FunctionalTemplate.mailer_queue_all(user, %{})
    assert {:ok, [%Dispatch{}]} = FunctionalTemplate.mailer_queue_all(e, %{})
  end

  test "get_from" do
    assert {:ok, "e@e"} =
             Template.Send.get_from(%Dispatch{assigns: %{a: "e@e"}, from_key: ["a"]})

    assert {:error, "Missing 'from'" <> _} =
             Template.Send.get_from(%Dispatch{assigns: %{}, from_key: ["a"]})
  end

  test "merge_assigns" do
    assert %{a: 1, b: 2} = Template.Send.merge_assigns(%{b: 2}, %{a: 1})
    assert %{a: 1, b: 3} = Template.Send.merge_assigns(%{b: 2}, %{a: 1, b: 3})

    assert %{a: 1, b: %{d: 1, e: 5}} =
             Template.Send.merge_assigns(%{b: %{d: 1}}, %{a: 1, b: %{e: 5}})
  end
end
