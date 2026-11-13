defmodule Rivet.Utils.BatchProcessor do
  @moduledoc """

  Process batches of items. Items are defined in a database table which has a
  few necessary fields (below).

  Each item is collected into a set of things to process in batches, but each
  item is run individually — correlate your handler functions accordingly.

  Configs are stored in the otp app's configs under the module name being defined,
  so in the below if the module is 'Core.Mailer' then it'll look in:

      config :core, Core.Mailer,
        enabled: true,
        # wait before checking for new changes
        check_interval: [10, 100],
        # wait between item callbacks on the same worker, if so desired. If not set to [1, 1]
        item_wait_interval: [1, 100],
        # how long to wait for a call (in milliseconds) to finish before saying its done and killing it
        item_call_timeout: 50

  use Rivet.Utils.BatchProcessor,
     otp_app: :core,
     # the Rivet model module
     model: Dispatch,
     # if left unspecified this defaults to the module name
     name: "Something"

   Required schema fields:

   id
   lock        - Nullable UUID, identifies the claiming batch
   locked_at   - Nullable UTC datetime, records claim time
   timestamps()

   batch_base_query/0 must return an Ecto query selecting
   only eligible, currently unlocked records.

   Locks are not automatically released on handler failure
   or timeout. External monitoring/recovery is required.
  A few notes:

  * timed-out items are locked indefinitely. We need to create an external
    monitor to review & alert on these.
  * need to reconcile CriticalFail import
  * add __MODULE__ to the supervision tree

  """

  @doc """
  Get a count of items pending in the Items table.
  """
  @callback count_pending() :: integer()

  @doc """
  The base query that is expanded upon when getting a batch.
  """
  @type id :: String.t() | integer()
  @callback batch_base_query() :: Ecto.Query.t()

  @doc """

  The item handler is called in a discrete process for each item, properly locked
  and handled.

  * It is not within a transaction, so if it needs to create any that is fine.
  * It should return the updated item or an error tuple for test observability ONLY.
  * In normal use the processor ignores any result.
  * It must finish before :item_call_timeout configured value (see above)

  """
  @callback item_handler!(id()) :: {:ok, any()} | {:error, any()}

  @doc """
  Used only for testing, but it will clear the queue/batch table of values.
  """
  @callback test_clear_pending_items() :: :ok
  @optional_callbacks test_clear_pending_items: 0

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer
      @behaviour Rivet.Utils.BatchProcessor
      import Ecto.Query, only: [from: 2, subquery: 1]
      require Logger
      @otp_app Keyword.fetch!(opts, :otp_app)
      @batch_model Keyword.fetch!(opts, :model)
      @module_name Keyword.get(opts, :name, inspect(Rivet.Utils.Module.mod_basename(__MODULE__)))

      @worker_supervisor __MODULE__.Supervisor

      defp getcfg(key), do: Application.fetch_env!(@otp_app, __MODULE__)[key]

      def set_enabled(bool) do
        env = Application.get_env(@otp_app, __MODULE__, [])
        Application.put_env(@otp_app, __MODULE__, Keyword.put(env, :enabled, bool))
      end

      ##########################################################################
      # genserver things
      def start_link(initial),
        # coveralls-ignore-next-line
        do: GenServer.start_link(__MODULE__, initial, name: __MODULE__)

      # start this AND a task supervisor
      def child_spec(initial) do
        children = [
          {Task.Supervisor, name: @worker_supervisor},
          %{
            id: {__MODULE__, :server},
            start: {__MODULE__, :start_link, [initial]},
            type: :worker
          }
        ]

        %{
          id: __MODULE__,
          start: {Supervisor, :start_link, [children, [strategy: :one_for_all]]},
          type: :supervisor
        }
      end

      @impl GenServer
      if Application.compile_env(@otp_app, :mode) != :test do
        def init(_) do
          ref = Process.send_after(self(), :process_queue, 0)
          {:ok, %{ref, last: 0}}
        end
      else
        # coveralls-ignore-next-line
        def init(_), do: {:ok, %{ref: nil, last: 0}}
      end

      # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
      @impl GenServer
      def handle_info(:process_queue, state) do
        if getcfg(:enabled) do
          pending = count_pending()

          if pending > 0 do
            batch_size = getcfg(:batch_size)
            workers = getcfg(:workers)

            Task.Supervisor.async_stream_nolink(
              @worker_supervisor,
              1..workers,
              fn _ -> process_batch(batch_size, pending) end,
              ordered: false,
              max_concurrency: workers,
              timeout: :infinity
            )
            |> Enum.each(fn
              {:ok, _} ->
                :ok

              # coveralls-ignore-next-line
              {:exit, reason} ->
                CriticalFail.report("#{@module_name}: worker crashed", reason: reason)
            end)

            # debug seperator
            # Logger.info("---------------------------------------------------------")
            %{state | last: Rivet.Utils.Time.now()}
          else
            state
          end
        else
          # coveralls-ignore-start
          Logger.warning("#{@module_name} is disabled")
          state
          # coveralls-ignore-stop
        end
        |> requeue_next()
      end

      ##############################################################################
      defp requeue_next(%{last: x} = state) do
        [base, wobble] = getcfg(:check_interval)

        interval =
          case Rivet.Utils.Time.now() - x do
            diff when diff * 1000 > base -> [base, wobble]
            # diff -> [diff * 1000, wobble]
            diff -> [max(base - diff * 1000, 0), wobble]
          end
          |> bobble_wait()

        ref = Process.send_after(self(), :process_queue, interval)

        #  interval = getcfg(:check_interval) |> bobble_wait()
        #  ref = Process.send_after(self(), :process_queue, interval)

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
      if Application.compile_env(@otp_app, __MODULE__)[:mode] == :test do
        def test_clear_pending_queue() do
          if getcfg(:enabled) do
            GenServer.call(__MODULE__, :test_clear_pending_queue, :infinity)
          else
            :ok
          end
        end

        @impl GenServer
        def handle_call(:test_clear_pending_queue, _from, state) do
          if state.ref, do: Process.cancel_timer(state.ref)

          test_clear_pending_items()
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

      def test_clear_pending_items(), do: :ok
      defoverridable test_clear_pending_items: 0

      # coveralls-ignore-stop

      ##############################################################################
      def get_batch(batch_size) do
        lock = Ecto.UUID.generate()
        now = DateTime.utc_now()

        picked =
          from(s in batch_base_query(),
            order_by: [asc: s.inserted_at, asc: s.id],
            limit: ^batch_size,
            lock: "FOR UPDATE SKIP LOCKED",
            select: s.id
          )

        from(i in @batch_model,
          # done as a subquery because PostgreSQL does not support ORDER BY or LIMIT
          # directly on an UPDATE; this gives us both in one query.
          where: i.id in subquery(picked),
          select: i.id
        )
        |> @batch_model.update_all(set: [lock: lock, locked_at: now, updated_at: now])
        |> case do
          {count, [_ | _] = ids} when count > 0 ->
            {:ok, lock, count, ids}

          {0, []} ->
            :none
        end
      rescue
        # coveralls-ignore-next-line
        err -> {:error, err}
      end

      ##############################################################################

      def process_batch(batch_size, pending) do
        if getcfg(:enabled) do
          case get_batch(batch_size) do
            {:ok, lock, count, ids} when count > 0 ->
              Logger.info("#{@module_name}: Processing batch",
                count: count,
                pending: pending,
                lock: lock
              )

              map = Enum.map(ids, &process_item_timed/1)

              Logger.info("#{@module_name}: Finished processing batch", lock: lock)

              {:ok, map}

            :none ->
              {:ok, []}

            {:error, reason} ->
              # this is a db error; hard to reproduce
              # coveralls-ignore-next-line
              report_abort("failed to claim items for batch processing", nil, reason)
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
            "#{@module_name} abort: #{msg}",
            Enum.reject([dispatch_id: id, reason: reason], fn {_, v} -> is_nil(v) end)
          )

      ##############################################################################
      # give each one a period to work within
      defp process_item_timed(id) do
        task = Task.Supervisor.async_nolink(@worker_supervisor, fn -> process_item(id) end)

        case Task.yield(task, getcfg(:item_call_timeout)) || Task.shutdown(task, :brutal_kill) do
          {:ok, _result} -> :ok
          {:exit, reason} -> report_abort("worker crashed", id, reason)
          nil -> report_abort("worker timed out", id)
        end
        |> tap(fn _ ->
          # slight pause between calls if so desired
          bobble_wait(getcfg(:item_wait_interval)) |> Process.sleep()
        end)
      end

      ##############################################################################
      defp process_item(id) do
        item_handler!(id)
      rescue
        # errors rising for other things outside of expected
        # coveralls-ignore-start
        err ->
          # IO.puts(Exception.format(:error, err, __STACKTRACE__))
          CriticalFail.stacktrace(@module_name, err, __STACKTRACE__, dispatch_id: id)
          # coveralls-ignore-stop
      end
    end
  end
end
