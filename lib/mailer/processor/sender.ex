defmodule Rivet.Mailer.Processor.Sender do
  use Rivet.Mailer

  def send(%Dispatch{} = d) do
    try do
      d.template.dispatch(d)
    rescue
      err -> {:stacktrace, err, __STACKTRACE__}
    end
    |> normalize_result()
    |> log_result(d)
    |> update_result(d)
  end

  ##############################################################################
  # NOTE: by setting the Rivet Template configuration `allow_recip: :email`, we
  # will only ever handle one email at a time in normalize_result.

  # Swoosh SES mailer result; in this case id=>sender_id (not even %Dispatch{} but
  # AWS SES sender id)
  def normalize_result({:ok, %{request_id, id}}),
    do: {:dispatched, %{request_id, sender_id: "ses:#{id}"}, []}

  # SMTP result
  def normalize_result({:ok, message}) when is_binary(message) do
    message =
      message
      |> String.trim()
      |> String.replace(~r/^\d\.\d\.\d\s+OK\s+/, "")
      # google smtp cleanup
      |> String.replace(~r/\s+-\s+gsmtp/, "")

    {:dispatched, %{message, sender_id: nil}, []}
  end

  # template hard blowout
  def normalize_result({:stacktrace, e, tb}),
    do: {:aborted, Exception.message(e), trace: Exception.format(:error, e, tb)}

  # template error during processing (before send)
  def normalize_result({:abort, error}), do: {:aborted, error, []}

  # dispatch_prep said to skip
  # coveralls-ignore-next-line
  def normalize_result({:skip, assigns}), do: {:skipped, assigns}

  # def normalize_result({:error, {:eval, msg, trace}, _}),
  #   do: {:aborted, "failed to eval template", error: msg, traceback: trace}
  #
  # # on Rivet email refactor fix this output pattern
  # def normalize_result({:error, {:unknown, {:error, {%CompileError{} = e, trace}}}, _}),
  #   do: {:aborted, "failed to compile template", error: e, traceback: trace}

  # {:error, "template missing", []}
  def normalize_result({:error, message, opts}) when is_binary(message) or is_atom(message),
    do: {:aborted, to_string(message), opts}

  # unexpected rivet/template/send error
  def normalize_result({:error, error}), do: {:aborted, error, []}

  # Mailer (swoosh) error
  def normalize_result({:error, %{code, message}, moar}),
    do: {:aborted, "#{code}: #{message}", moar}

  # {:error, :closed, []} !?? - this is probably needing to be fixed in Rivet.Mailer.Template
  # fallback
  def normalize_result(other) do
    # Shutdown if something weird happens
    Mailer.enabled(false)
    CriticalFail.report("MAILER DISABLED due to unexpected result")
    {:aborted, "Mailer DISABLED: unexpected result shape", response: other}
  end

  ##############################################################################
  # slight sugar to make lines shorter
  def aborted(msg, d, opts),
    do: CriticalFail.report("Mailer abort: #{msg}", opts ++ [dispatch_id: d.id])

  ##############################################################################
  # future: EMS.SysError
  defp log_result({:aborted, err, opts}, %Dispatch{} = d) when is_map(err) do
    aborted("error sending email", d, opts ++ [error: err])

    {:aborted, %{message: inspect(err)}, opts}
  end

  defp log_result({:aborted, msg, opts}, %Dispatch{} = d) do
    aborted("error sending email", d, opts ++ [message: msg])

    {:aborted, %{message: msg}, opts}
  end

  defp log_result({:skipped, assigns}, %Dispatch{} = d) do
    Logger.warning("skipping email dispatch", assigns: assigns, dispatch_id: d.id)

    # ############################################################################
    # #                                                                          #
    # # short-circuit hackery until Rivet.Mailer allows this without sending      #
    # #                                                                          #
    # {:ok, config} = Rivet.Mailer.Config.load_site("")
    #
    # from_key = Map.get(assigns, :from_key, [:addrs, :from])
    #
    # assigns = Map.merge(config, assigns)
    #
    # assigns =
    #   put_in(assigns, from_key, get_in(assigns, from_key))
    #   |> Map.put(:recipient, d.target.email)
    #
    # case d.template.generate(d.target.email, assigns) do
    #   {:ok, s, b} ->
    #     IO.puts("\n\nSUBJECT: #{s}\n")
    #     IO.puts(b)
    #     IO.puts("\n\n")
    #
    #   {:error, ugly} ->
    #     {:ok, t} = Rivet.Mailer.Template.one(name: "#{d.template}")
    #     IO.puts("\n---------------TEMPLATE #{d.template}\n")
    #     IO.puts(t.data)
    #     IO.puts("\n-------------------------------------\n")
    #     IO.inspect(ugly)
    #     IO.puts("Waiting 5 seconds...")
    #     Process.sleep(5000)
    # end
    #
    # #                                                                          #
    # #                                                                          #
    # ############################################################################

    {:skipped, %{message: "skipped"}, []}
  end

  defp log_result({:dispatched, _, opts} = pass, %Dispatch{} = d) do
    template = inspect(d.template) |> String.replace("Rivet.Mailer.Template.", "")

    Logger.info(
      "Mailer: email dispatched",
      opts ++ [template: template, user_id: d.target.user_id, dispatch_id: d.id]
    )

    pass
  end

  ##############################################################################
  defp update_result({status, result, _}, %Dispatch{} = d) do
    Mailer.module_for(:repo).transact(fn ->
      with {:ok, update, {status, log}} <- build_dispatch_update_(status, result),
           {:ok, d} <- Dispatch.update(d, update),
           {:ok, _} <- Dispatch.Log.create(%{dispatch_id: d.id, type: status, value: log}) do
        {:ok, d}
      else
        {:error, x} ->
          # coveralls-ignore-next-line
          aborted("failed to update Dispatch", d, reason: CriticalFail.nice_error(x))
      end
    end)
  end

  ##############################################################################
  defp build_dispatch_update_(:dispatched = status, %{sender_id}) do
    {:ok, Map.merge(%{lock: nil, sent_at: DateTime.utc_now()}, %{status, sender_id}),
     {status, %{message: "dispatched"}}}
  end

  defp build_dispatch_update_(status, log),
    do: {:ok, %{status, lock: nil}, {status, log}}
end
