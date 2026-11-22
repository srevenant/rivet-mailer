defmodule Rivet.Mailer.CriticalFail do
  @moduledoc """

  Yes its a template, but not in templates because this is an integral part
  of the whole system, not optional.

  """

  use Rivet.Mailer.Template
  use Rivet.Mailer
  import Rivet.Utils.Map, only: [to_string_keqv: 1]
  import Rivet.Utils.UniformLogFormat, only: [format_msg: 2]

  # gymnastics for test, only set this in test config
  @handler Application.compile_env(:rivet_mailer, :critical_fail) || false

  if @handler == false do
    defp get_handler(), do: __MODULE__
  else
    defp get_handler(), do: Application.get_env(:rivet_mailer, :critical_fail)
  end

  def report(a, b \\ []), do: get_handler().report_(a, b)

  ##############################################################################
  # coveralls-ignore-start
  def report_(error, info \\ []) do
    log = nice_error(error)
    Logger.error(log, info)

    # Task so we split out of any transaction that is being aborted, because
    # deliver still makes a db call and thus fails if we are in an aborting transaction
    Task.start(fn -> deliver_now(:errors, %{log, info: format_msg([], info)}) end)

    {:error, log}
  end

  # coveralls-ignore-stop

  ##############################################################################
  # this forces opts into the email message itself. beware
  # coveralls-ignore-start
  def dangerous_report_with_opts(error, info) do
    log = nice_error(error)
    Logger.error(log, info)

    Task.start(fn ->
      deliver_now(:errors, %{log: "#{log}: #{to_string_keqv(info)}", info: ""})
    end)

    {:error, error}
  end

  # coveralls-ignore-stop

  ##############################################################################
  # coveralls-ignore-start
  def deliver_now(email_key, assigns) when is_atom(email_key) do
    with {:ok, %Dispatch{} = d} <- create_dispatch(email_key, assigns),
         do: Mailer.Processor.Sender.send(d)
  end

  # coveralls-ignore-stop

  def create_dispatch(email_key, assigns) do
    opts = [force: true, lock: Ecto.UUID.generate(), locked_at: DateTime.utc_now()]

    with {:ok, recip} <- Mailer.Tools.Email.direct_email_address(email_key),
         {:ok, d} <- mailer_queue(recip, assigns, opts),
         {:ok, d} <- Dispatch.preload(d, target: [:email, :user]) do
      {:ok, d}
    else
      {:error, reason} = error ->
        # coveralls-ignore-start
        Logger.error("Failed to create CriticalFail dispatch", reason: reason)
        error
        # coveralls-ignore-stop
    end
  end

  ##############################################################################
  def report_if_error(a, b \\ nil, c \\ [])

  def report_if_error({:error, msg}, nil, info), do: report(nice_error(msg), info)

  def report_if_error({:error, m2} = pass, msg, info) do
    report("#{msg}: #{nice_error(m2)}", info)
    pass
  end

  def report_if_error({:error, m2, _} = pass, msg, info) do
    report("#{msg}: #{nice_error(m2)}", info)
    pass
  end

  def report_if_error(pass, _, _), do: pass

  ######
  def nice_error(%Ecto.Changeset{errors}) do
    Enum.reduce(errors, [], fn {field, {message, opts}}, accum ->
      message =
        Enum.reduce(opts, message, fn {key, value}, message ->
          String.replace(message, "%{#{key}}", inspect(value))
        end)

      ["#{field} #{message}" | accum]
    end)
    |> Enum.join(", ")
  end

  def nice_error(message) when is_binary(message), do: message
  def nice_error(hrm), do: inspect(hrm)

  ######
  def stacktrace(origin, error, trace, opts \\ []) do
    report(
      "Stacktrace in #{origin}: #{Exception.message(error)}",
      opts ++ [trace: Exception.format(:error, error, trace)]
    )
  end

  @doc """

  Spin off a task and log through CriticalFail if it blows out.

  """
  # coveralls-ignore-next-line
  def unattended_task(func), do: Task.start(fn -> run_unattended_task(func) end)

  def run_unattended_task(func) do
    func.()
  rescue
    err ->
      formatted = Exception.format(:error, err, __STACKTRACE__)
      CriticalFail.report("Unattended task crashed", error: err, traceback: formatted)
  catch
    err, info ->
      # coveralls-ignore-start
      IO.inspect({err, info}, label: "Unattended error")
      {:traceback, {err, info}, __STACKTRACE__}
      # coveralls-ignore-stop
  end
end
