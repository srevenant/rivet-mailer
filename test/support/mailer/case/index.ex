defmodule Test.Support.Mailer.Case do
  use ExUnit.CaseTemplate

  using(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Rivet.Guards
      import Test.Support.Mailer.Factories
      import ExUnit.CaptureLog
      use Rivet.Mailer
      alias Rivet.Mailer.Dispatch
      alias Test.Support.Unique
      alias Ecto.Changeset
      require Logger

      def logged(log) do
        Logger.info(log)
        log
      end

      def check_expected(result, [expect | rest]) do
        assert result =~ expect
        check_expected(result, rest)
      end

      def check_expected(result, []), do: result

      def check_expected(result, expected), do: check_expected(result, [expected])

      def do_dispatch(template, %Dispatch{} = d) do
        with {:ok, d} <- Dispatch.preload(d, target: [:email, :user]),
             do: Rivet.Mailer.Processor.Sender.send(d)
      end

      # don't wait for processor, just send it straight into dispatch
      def expect_queue(mod, args, expected) do
        expectx(
          mod,
          fn ->
            assert {:ok, %Dispatch{} = d} = apply(mod, :queue, args)
            do_dispatch(mod, d)
          end,
          expected
        )
      end

      ##########################################################################
      # bypass needed because DB connection privs don't work right when in tests
      # and it is in the subprocess
      def expect_bypass(a, b, c)

      # def expect_bypass(mod, [[_, target], assigns], expected) when not_empty_str(target),
      #   do: expect_bypass_(mod, [target, assigns], expected)

      # def expect_bypass(a, b, c), do: expect_bypass_(a, b, c)

      ########
      def expect_bypass(mod, [dispatch, assigns], expected),
        do: expectx(mod, fn -> mod.dispatch(dispatch, assigns) end, expected)

      @div "--------------------"
      defp run_enrich_error(func, template) do
        with {:error, {:eval, msg, x}, _} <- func.(),
             {:ok, t} <- Rivet.Mailer.Template.one(name: "#{template}") do
          IO.puts([@div, " RAW TEMPLATE #{template}\n\n", t.data, "\n"])

          String.split(t.data, ~r/\n===(.*)$/m, include_captures: true)
          |> Enum.each(fn
            "" ->
              :ok

            "=== rivet-template-v1" <> _ ->
              :ok

            "\n=== " <> type ->
              IO.puts(["\n", @div, " ", type, "\n"])

            section ->
              String.split(section, ~r/\n/)
              |> Enum.with_index(fn
                "", 0 ->
                  :ok

                line, x ->
                  IO.puts([String.pad_leading("#{x}: ", 5), line])
              end)
          end)

          IO.puts(["\n", @div, " TEMPLATE ERROR:\n\n", msg, "\n"])

          case x do
            [] -> :ok
            list -> IO.inspect(x, label: "case.notify error")
          end

          IO.puts(["\n", @div, "\n"])

          {:error, {:eval, msg, template, t.data}}
        end
      end

      def expectx(template, func, expected) do
        capture_log(fn ->
          assert {:ok, %Dispatch{}} = run_enrich_error(func, template)
        end)
        |> check_expected(expected)

        # stops async errors happening after test exits
        # |> tap(fn _ -> Rivet.Mailer.Processor.test_clear_pending() end)
      end
    end
  end

  use Rivet.Mailer
  alias Ecto.Adapters.SQL.Sandbox

  @accessors [Rivet.Mailer.Processor]

  setup do
    owner = Sandbox.start_owner!(@repo, shared: false)

    sandbox_allow_processes(owner, @accessors)

    ExUnit.Callbacks.on_exit(fn ->
      # Rivet.Mailer.Processor.test_clear_pending()
      Rivet.Mailer.enabled(false)
      Application.put_env(:rivet_mailer, :mode, :test)
      Sandbox.stop_owner(owner)
    end)

    {:ok, sandbox_owner: owner}
  end

  def sandbox_allow(owner, mod) do
    case Process.whereis(mod) do
      nil ->
        :ok

      pid ->
        Sandbox.allow(@repo, owner, pid) in [:ok, {:already, :allowed}, {:already, :owner}]
    end
  end

  def sandbox_allow_processes(owner, list), do: Enum.each(list, &sandbox_allow(owner, &1))
end
