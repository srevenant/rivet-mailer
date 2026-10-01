defmodule Rivet.Mailer.Processor.Batch do
  use Rivet.Mailer
  require Logger
  alias Rivet.Mailer.Dispatch.Lib, as: DispatchLib

  def process(batch_size, pending) do
    if Mailer.getcfg(:enabled) do
      case DispatchLib.get_batch(batch_size) do
        {:ok, lock, count, ids} when count > 0 ->
          Logger.info("Mailer: Processing pending dispatches",
            count: count,
            pending: pending,
            lock: lock
          )

          map = Enum.map(ids, &process_send_timed/1)

          Logger.info("Mailer: Finished processing dispatches", lock: lock)

          {:ok, map}

        :none ->
          {:ok, []}

        {:error, reason} ->
          # this is a db error; hard to reproduce
          # coveralls-ignore-next-line
          report_abort("failed to claim dispatches for batch processing", nil, reason)
      end
    else
      {:ok, [:disabled]}
    end
  end

  ##############################################################################
  # slight sugar to make lines shorter
  def report_abort(msg, id, reason \\ nil),
    do:
      CriticalFail.report(
        "Mailer abort: #{msg}",
        Enum.reject([dispatch_id: id, reason: reason], fn {_, v} -> is_nil(v) end)
      )

  ##############################################################################
  # give each one a period to work within
  defp process_send_timed(id) do
    task = Task.Supervisor.async_nolink(@worker_supervisor, fn -> process_send(id) end)

    case Task.yield(task, @send_timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, _result} -> :ok
      {:exit, reason} -> report_abort("dispatch worker crashed", id, reason)
      nil -> report_abort("dispatch worker timed out", id)
    end
    |> tap(fn _ ->
      # slight pause between calls so we don't hammer our relay
      Processor.bobble_wait(@send_interval) |> Process.sleep()
    end)
  end

  ##############################################################################
  defp process_send(id) do
    case Dispatch.one([id: id], target: [:email, user: [:handle]]) do
      {:ok, d} -> Processor.Sender.send(d)
      # this is a db error; hard to reproduce
      # coveralls-ignore-next-line
      {:error, reason} -> report_abort("unable to load dispatch", id, reason)
    end
  rescue
    # errors rising for other things outside of expected
    # coveralls-ignore-start
    err ->
      # IO.puts(Exception.format(:error, err, __STACKTRACE__))
      CriticalFail.stacktrace("Mailer", err, __STACKTRACE__, dispatch_id: id)
      # coveralls-ignore-stop
  end
end
