defmodule Rivet.Mailer.Processor do
  @moduledoc """

  There are three result paths in play, and how status/locks change because of them:

  DISPATCHED - provider says success
    status = :dispatched
    lock = nil

  ABORTED - anything we regard as terminal failure
    status = :aborted
    lock = nil

  RETRYABLE - specifically recognized failure where we know retry is appropriate
    status = :pending
    lock = nil

  TODO: A separate cron process that looks for stranded/failed things (ABORTED).
    There are two scenarios to appear in this report:

    - status = :aborted  (perhaps we need a separate confirmed_aborted status to keep it from the daily report)
    - status = :pending but a lock remains after too long a period

  """

  use GenServer
  use Rivet.Mailer
  require Logger
  alias Rivet.Mailer.Dispatch.Lib, as: DispatchLib

  def enabled(bool), do: Application.put_env(:rivet_mailer, :enabled, bool)

  def start_link(initial),
    do: GenServer.start_link(__MODULE__, initial, name: __MODULE__)

  @impl GenServer
  if Application.compile_env(:rivet_mailer, :mode) != :test do
    def init(_) do
      ref = Process.send_after(self(), :process_queue, 0)
      {:ok, %{ref, last: 0}}
    end
  else
    def init(_), do: {:ok, %{ref: nil, last: 0}}
  end

  ##############################################################################
  @impl GenServer
  def handle_info(:process_queue, state) do
    if Mailer.getcfg(:enabled) do
      pending = DispatchLib.count_pending()

      if pending > 0 do
        batch_size = Mailer.getcfg(:batch_size)
        workers = Mailer.getcfg(:workers)

        Task.Supervisor.async_stream_nolink(
          :mailer_worker_supervisor,
          1..workers,
          fn _ -> Processor.Batch.process(batch_size, pending) end,
          ordered: false,
          max_concurrency: workers,
          timeout: :infinity
        )
        |> Enum.each(fn
          {:ok, _} -> :ok
          # coveralls-ignore-next-line
          {:exit, reason} -> CriticalFail.report("Mailer: worker crashed", reason: reason)
        end)

        # debug seperator
        # Logger.info("---------------------------------------------------------")
        %{state | last: Rivet.Utils.Time.now()}
      else
        # Logger.info("Mailer: nothing in queue")
        state
      end
    else
      # coveralls-ignore-start
      Logger.warning("Mailer is disabled")
      state
      # coveralls-ignore-stop
    end
    |> monitor_queue_size(DispatchLib.count_pending())
    |> requeue_next()
  end

  # TODO: Add something to monitor queue size and alert if its getting too big
  defp monitor_queue_size(state, x), do: {state, x}

  ##############################################################################
  # This waits a bit based on if there's anything pending (:batch_interval_pending)
  # or if nothing is pending it backs off to the max (:batch_interval_none)
  defp requeue_next({%{last: x} = state, pending}) do
    interval =
      if pending > 0 do
        # bobbling with multiple pending calls eh. We already run bobble wait
        # below in tests so skip this one -BJG
        # coveralls-ignore-next-line
        bobble_wait(@batch_interval_pending)
      else
        [base, wobble] = @batch_interval_none

        case Rivet.Utils.Time.now() - x do
          diff when diff * 1000 > base -> [base, wobble]
          diff -> [diff * 1000, wobble]
        end
        |> bobble_wait()
      end

    ref = Process.send_after(self(), :process_queue, interval)

    {:noreply, %{state | ref}}
  end

  def bobble_wait([base, rand]), do: base + :rand.uniform(rand)

  ##############################################################################
  #
  # only used by testing, so we don't have it running stuff when it shouldn't
  # be, on_exit processes can call this.
  #
  # Because of the way this works, if an active process_queue is running and this
  # is called, the caller will block until the processing is finished and then this
  # clears anything left in the db, so it should be fine after that.
  #
  # coveralls-ignore-start
  if Application.compile_env(:rivet_mailer, :mode) == :test do
    def test_clear_pending() do
      if Mailer.getcfg(:enabled) do
        GenServer.call(__MODULE__, :test_clear_pending, :infinity)
      else
        :ok
      end
    end

    @impl GenServer
    def handle_call(:test_clear_pending, _from, state) do
      if state.ref, do: Process.cancel_timer(state.ref)

      DispatchLib.test_clear_pending()
      flush_receive()
      {:reply, :ok, state}
    end

    defp flush_receive() do
      receive do
        :process_queue -> flush_receive()
      after
        0 -> :ok
      end
    end
  end

  # coveralls-ignore-stop
end
