defmodule Test.WebSvc.Controllers.EmailSesTest do
  use Test.Support.Web.Case.Conn
  import ExUnit.CaptureLog
  alias Core.Db.Ident.Email
  alias Rivet.Mailer.Dispatch

  import Test.Support.Web.MockSns

  @path "/v1/api/ses"
  @topic Application.compile_env!(:web, :aws_email_topic)

  ##############################################################################
  setup %{conn} do
    conn = put_req_header(conn, "content-type", "text/plain; charset=UTF-8")

    {:ok,
     %{
       conn,
       post: fn map ->
         data = Jason.encode!(map)
         post(conn, @path, data)
       end
     }}
  end

  defp test_for(data, post, code, rex) do
    assert capture_log(fn -> post.(data) |> response(code) end) =~ rex
  end

  ##############################################################################
  defp test_ses_confirm(post, expect, code, log) do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "GET", "/callback", fn conn ->
      Plug.Conn.resp(conn, code, "")
    end)

    mock_ses_confirm("http://localhost:#{bypass.port}/callback")
    |> test_for(post, expect, log)
  end

  test "(un)subscription confirmation", %{post} do
    test_ses_confirm(post, 204, 200, ~r/EmailSes subscription confirmed/)
    test_ses_confirm(post, 500, 505, ~r/SNS subscription confirmation returned HTTP 505/)

    # no mock, failed URL
    mock_ses_confirm("http://localhost/callback")
    |> test_for(post, 500, ~r/SNS subscription confirmation failed: :econnrefused/)

    mock_ses_confirm("ignored", "UnsubscribeConfirmation")
    |> test_for(post, 204, ~r/subscription removed/)

    assert {:ok, :no_content, :error, "subscription confirmed", []} =
             WebSvc.Controllers.EmailSes.handle_notification(%{
               "notificationType" => "AmazonSnsSubscriptionSucceeded"
             })
  end

  ##############################################################################
  test "delivered", %{post} do
    assert %{status: :dispatched} = d = insert_dispatched()
    assert %{status: :pending, verified: true} = Email.one!(id: d.target.email_id)

    # test bad senderId first
    mock_ses_delivered(%{d | sender_id: "narf"})
    |> test_for(
      post,
      :service_unavailable,
      ~r/message received out of order\? cannot find sender_id/
    )

    mock_ses_delivered(d) |> test_for(post, :no_content, ~r/EmailSes delivery/)

    assert %{
             status: :delivered,
             logs: [%{type: :delivered, value: %{"response" => "250 2.0.0 OK"}, issue_id: nil}]
           } = Dispatch.one!([id: d.id], [:logs])

    # still pending because delivered does not update Email
    assert %{status: :pending, issues: []} = Email.one!([id: d.target.email_id], [:issues])
  end

  ##############################################################################
  test "bounced", %{post} do
    assert %{status: :dispatched} = d = insert_dispatched()
    assert %{status: :pending} = Email.one!(id: d.target.email_id)
    mock_ses_bounced1(d) |> test_for(post, :no_content, ~r/EmailSes bounce/)

    assert %{
             status: :failed,
             logs: [
               %Dispatch.Log{
                 type: :bouncing,
                 value: nil,
                 issue: %Email.Issue{issue, type: :bouncing}
               }
             ]
           } =
             Dispatch.one!([id: d.id], logs: [:issue])

    assert %{
             "action" => "failed",
             "address" => "recipient@example.com",
             "code" => "smtp; 550 5.1.1 user unknown",
             "bounce_sub_type" => "General",
             "bounce_type" => "Permanent"
           } == issue

    mock_ses_bounced2(d) |> test_for(post, :no_content, ~r/EmailSes bounce/)

    assert %{
             status: :failed,
             logs: [
               _,
               %Dispatch.Log{
                 type: :bouncing,
                 value: nil,
                 issue: %Email.Issue{issue, type: :bouncing}
               }
             ]
           } =
             Dispatch.one!([id: d.id], logs: [:issue])

    assert %{
             "address" => "recipient@example.com",
             "bounce_sub_type" => "General",
             "bounce_type" => "Permanent"
           } == issue
  end

  ##############################################################################
  test "complaint", %{post} do
    assert %{status: :dispatched} = d = insert_dispatched()
    assert %{status: :pending} = Email.one!(id: d.target.email_id)
    mock_ses_complaint(d) |> test_for(post, :no_content, ~r/EmailSes complaint/)

    assert %{
             status: :failed,
             logs: [
               %Dispatch.Log{
                 type: :complaint,
                 value: nil,
                 issue: %Email.Issue{
                   type: :complaint,
                   issue: %{
                     "address" => "recipient@example.com",
                     "type" => "abuse"
                   }
                 }
               }
             ]
           } =
             Dispatch.one!([id: d.id], logs: [:issue])
  end

  ##############################################################################
  test "rejected", %{post} do
    assert %{status: :dispatched} = d = insert_dispatched()
    assert %{status: :pending} = Email.one!(id: d.target.email_id)
    mock_ses_rejected(d) |> test_for(post, :no_content, ~r/EmailSes reject/)

    assert %{
             status: :failed,
             logs: [
               %Dispatch.Log{
                 type: :rejected,
                 value: nil,
                 issue: %Email.Issue{
                   type: :rejected,
                   issue: %{"reason" => "Bad content"}
                 }
               }
             ]
           } =
             Dispatch.one!([id: d.id], logs: [:issue])
  end

  ##############################################################################
  test "bad", %{post} do
    %{"nope" => 1} |> test_for(post, :forbidden, ~r/invalid data shape/)

    %{"TopicArn" => @topic, "expect" => "nomsg"}
    |> test_for(post, :forbidden, ~r/invalid message.*reason="Missing message type parameter/)

    %{"TopicArn" => "bad", "expect" => "nomsg", "Type" => "Notification"}
    |> test_for(post, :forbidden, ~r/invalid TopicArn/)
  end

  # this is the rare DB case that'd kick up some dust but is hard to test
  test "internal error", %{conn} do
    assert capture_log(fn ->
             WebSvc.Controllers.EmailSes.handle_result({:error, %Ecto.Changeset{}}, conn)
             |> response(:internal_server_error)
           end) =~ ~r/EmailSes internal error.*Changeset/
  end

  ##############################################################################
  test "unexpected notification", %{post} do
    assert %{status: :dispatched} = d = insert_dispatched()
    assert %{status: :pending} = Email.one!(id: d.target.email_id)

    mock_ses_unexpected_notification(d)
    |> test_for(post, :bad_request, ~r/EmailSes unexpected notification type/)
  end

  ##############################################################################
  test "unexpected message", %{post} do
    assert %{status: :dispatched} = d = insert_dispatched()
    assert %{status: :pending} = Email.one!(id: d.target.email_id)

    mock_ses_unexpected_message()
    |> test_for(post, :bad_request, ~r/EmailSes unexpected message type/)
  end

  ##############################################################################
  test "bork_message", %{post} do
    assert %{status: :dispatched} = d = insert_dispatched()
    assert %{status: :pending} = Email.one!(id: d.target.email_id)

    mock_ses_rejected(d)
    |> Map.put("Message", "{\"garbled")
    |> test_for(post, :bad_request, ~r/EmailSes error: payload parse failed/)
  end

  ##############################################################################
  test "invalid SNS POST", %{conn} do
    conn
    |> put_req_header("content-type", "text/plain; charset=UTF-8")
    |> post(@path, "{garbled")
    |> response(:bad_request)
  end

  # # internal system error/unexpected error
end
