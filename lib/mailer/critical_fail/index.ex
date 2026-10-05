defmodule Rivet.Mailer.CriticalFail do
  @moduledoc """

  Yes its a template, but not in templates because this is an integral part
  of the whole system, not optional.

  """

  use Rivet.Mailer.Template
  use Rivet.Mailer
  import Rivet.Utils.UniformLogFormat, only: [format_msg: 2]

  # gymnastics for test, only set this in test config
  @handler Application.compile_env(:rivet_mailer, :critical_fail) || false

  if @handler == false do
    defp get_handler(), do: __MODULE__
  else
    defp get_handler(), do: Application.get_env(:rivet_mailer, :critical_fail)
  end

  def report(a, b \\ []), do: get_handler().report_(a, b)

  # coveralls-ignore-start
  def report_(error, info \\ []) do
    Logger.error(error, info)

    # Task so we split out of any transaction that is being aborted, because
    # deliver still makes a db call and thus fails if we are in an aborting transaction
    Task.start(fn -> deliver_now(:errors, %{log: error, info: format_msg([], info)}) end)

    {:error, error}
  end

  # this forces opts into the email message itself. beware
  def dangerous_report_with_opts(log, info) do
    Logger.error(log, info)

    Task.start(fn -> deliver_now(:errors, %{log: "#{log} #{kv_string(info)}", info: ""}) end)

    {:error, log}
  end

  ##############################################################################
  def deliver_now(email_key, assigns) when is_atom(email_key) do
    with {:ok, %Dispatch{} = d} <- create_dispatch(email_key, assigns),
         do: Mailer.Processor.Sender.send(d)
  end

  def create_dispatch(email_key, assigns) do
    with {:ok, recip} <- Mailer.Tools.Email.direct_email_address(email_key),
         {:error, r} <- mailer_queue(recip, assigns, force: true),
         do: Logger.error("Failed to create CriticalFail dispatch", reason: r)
  end

  ##############################################################################

  # need to update this in Rivet.Utils so it's more accessible
  defp kv_string(data),
    do: Rivet.Utils.UniformLogFormat.format_msg(data, %{}) |> IO.iodata_to_binary()

  #######
  def report_if_error(a, b \\ nil, c \\ [])

  def report_if_error({:error, msg}, nil, info), do: report(nice_error(msg), info)

  def report_if_error({:error, m2}, msg, info) do
    report("#{msg}: #{nice_error(m2)}", info)
    {:error, m2}
  end

  def report_if_error({:error, m2, _}, msg, info) do
    report("#{msg}: #{nice_error(m2)}", info)
    {:error, m2}
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
  def stacktrace(origin, error, trace, opts \\ []),
    do:
      report(
        "Stacktrace in #{origin}: #{Exception.message(error)}",
        opts ++ [trace: Exception.format(:error, error, trace)]
      )

  # coveralls-ignore-stop
end
