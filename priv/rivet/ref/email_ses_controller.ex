defmodule WebSvc.Controllers.EmailSes do
  use WebSvc, :controller
  alias Rivet.Mailer.{Dispatch, CriticalFail}
  require Logger

  @moduledoc """
  https://docs.aws.amazon.com/ses/latest/dg/event-publishing-retrieving-sns-examples.html
  """

  @sns_mod Application.compile_env(:web, :aws_sns) || ExAws.SNS

  # because AWS in their wisdom doesn't add content-type: application/json
  def sns_post(c, _params) do
    with {:ok, body, c} <- Plug.Conn.read_body(c),
         {:ok, data} <- Jason.decode(body) do
      Application.get_env(:web, :aws_email_topic) |> response(c, data)
    else
      {:error, %Jason.DecodeError{} = error} ->
        error("Invalid SNS POST: #{Exception.message(error)}")
        handle_result({:rest, :bad_request}, c)
    end
  end

  # high level case to allow individual functions for each type
  def response(topic_arn, c, %{"TopicArn" => topic_arn} = args) do
    # with :cont <- Throttle.throttle(...)
    #  NOTE: set it really high; but can be set with errors
    case {@sns_mod.verify_message(args), args["Type"]} do
      {:ok, "Notification"} -> with_json(args["Message"], &handle_notification/1)
      {:ok, "SubscriptionConfirmation"} -> handle_confirmation(args)
      {:ok, "UnsubscribeConfirmation"} -> {:ok, :no_content, :error, "subscription removed", []}
      {{:error, x}, y} -> handle_invalid_message(x, y)
      {:ok, other} -> handle_unexpected_message(other)
    end
    # |> throttle_malicious()
    |> handle_result(c)
  end

  def response(_, c, %{"TopicArn" => notmine}) do
    error("invalid TopicArn", value: notmine)
    handle_result({:rest, :forbidden}, c)
  end

  def response(_, c, _d) do
    # IO.inspect(d)
    error("invalid data shape")
    # Throttle.malicious(...)
    handle_result({:rest, :forbidden}, c)
  end

  ##############################################################################
  def handle_result({:rest, code}, conn), do: send_resp(conn, code, "")

  def handle_result({:ok, response, log_type, log_msg, syslog}, conn) do
    app_log(log_msg, log_type, syslog)
    send_resp(conn, response, "")
  end

  def handle_result({:error, msg}, conn) do
    CriticalFail.report("EmailSes internal error", msg: msg)
    send_resp(conn, :internal_server_error, "")
  end

  ##############################################################################
  defp with_json(data, callback) do
    case Jason.decode(data) do
      {:ok, data} ->
        callback.(data)

      {:error, why} ->
        error("payload parse failed: #{Exception.message(why)}", json: data)
        {:rest, :bad_request}
    end
  end

  ##############################################################################
  defp handle_invalid_message(reason, type),
    do: {:ok, :forbidden, :error, "invalid message", type: type, reason: reason}

  ##############################################################################
  defp handle_unexpected_message(type),
    do: {:ok, :bad_request, :error, "unexpected message type", type: type}

  ################################################################################
  def handle_confirmation(%{"SubscribeURL" => url}) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        {:ok, :no_content, :info, "subscription confirmed", []}

      {:ok, %HTTPoison.Response{status_code}} ->
        {:error, "SNS subscription confirmation returned HTTP #{status_code}"}

      {:error, %HTTPoison.Error{reason}} ->
        {:error, "SNS subscription confirmation failed: #{inspect(reason)}"}
    end
  end

  ##############################################################################
  def handle_notification(%{"mail" => %{"messageId" => sender_id}} = raw) do
    with {:ok, {log_level, type, data}} <- normalize_event_shape(raw) do
      %{dispatch, dispatch_log, syslog} = normalize_event(type, data)

      case Dispatch.Log.add(:ses, dispatch, "ses:#{sender_id}", dispatch_log) do
        {:ok, dispatch_id} ->
          {:ok, :no_content, log_level, to_string(type), syslog ++ [dispatch_id: dispatch_id]}

        {:error, :not_found} ->
          {:ok, :service_unavailable, :warning,
           "message received out of order? cannot find sender_id",
           syslog ++ [sender_id: sender_id]}
      end
    end
  end

  def handle_notification(%{"notificationType" => "AmazonSnsSubscriptionSucceeded"}),
    do: {:ok, :no_content, :error, "subscription confirmed", []}

  ##############################################################################
  defp normalize_event_shape(%{"delivery" => d}), do: {:ok, {:info, :delivery, d}}
  defp normalize_event_shape(%{"bounce" => d}), do: {:ok, {:error, :bounce, d}}
  defp normalize_event_shape(%{"complaint" => d}), do: {:ok, {:error, :complaint, d}}
  defp normalize_event_shape(%{"reject" => d}), do: {:ok, {:error, :reject, d}}

  defp normalize_event_shape(d),
    do: {:ok, :bad_request, :error, "unexpected notification type", msg: d}

  ##############################################################################
  defp normalize_event(:delivery, %{"recipients" => [_]} = d) do
    %{
      dispatch: :delivered,
      dispatch_log: %{type: :delivered, log: %{response: d["smtpResponse"]}},
      syslog: []
    }
  end

  defp normalize_event(:bounce, %{"bouncedRecipients" => [e]} = b) do
    # NOTE type=Permanent vs type={other} like Transient/whatever should be handled
    # differently... perhaps only on Permanent does Email get updated to unverified?
    log = extract_bounce_log(b, e)

    %{
      dispatch: :failed,
      dispatch_log: %{type: :bouncing, log: log},
      # log.type is also there but is the SES type, not the Dispatch.Log type
      syslog: Map.take(log, [:type, :action, :code]) |> Map.to_list()
    }
  end

  defp normalize_event(:complaint, %{"complainedRecipients" => [e]} = c) do
    log = %{address: e["emailAddress"], type: c["complaintFeedbackType"]}

    %{
      dispatch: :failed,
      dispatch_log: %{type: :complaint, log: log},
      syslog: [type: log.type]
    }
  end

  defp normalize_event(:reject, %{"reason" => reason}) do
    CriticalFail.report("Rejected email?", reason: reason)
    # {:rejected, %{reason}, reason: reason}
    %{
      dispatch: :failed,
      dispatch_log: %{type: :rejected, log: %{reason}},
      syslog: [reason: reason]
    }
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  defp extract_bounce_log(d, e) do
    bounce_types = Map.take(d, ["bounceType", "bounceSubType"]) |> Transmogrify.transmogrify()
    extracted = extract_bounce_log_(e)
    Map.merge(extracted, bounce_types)
  end

  defp extract_bounce_log_(%{
         "action" => action,
         "diagnosticCode" => code,
         "emailAddress" => address
       }),
       do: %{action, code, address}

  defp extract_bounce_log_(%{"emailAddress" => address}), do: %{address}

  ################################################################################
  defp error(msg, opts \\ []), do: app_log("error: #{msg}", :error, opts)
  defp app_log(msg, level, opts), do: Logger.log(level, "EmailSes #{msg}", opts)
end
