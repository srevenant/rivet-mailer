defmodule Rivet.Mailer.Test.CriticalFail.IndexTest do
  use Rivet.Mailer.Test.Case
  import ExUnit.CaptureLog
  alias Rivet.Mailer.CriticalFail

  test "report_if_error" do
    assert capture_log(fn ->
             assert {:error, "msg", 2} = CriticalFail.report_if_error({:error, "msg", 2})
             assert {:error, _} = CriticalFail.report_if_error({:error, 1})
             assert {:ok, :fine} = CriticalFail.report_if_error({:ok, :fine})
             assert :ok = CriticalFail.report_if_error(:ok)
           end) =~ ~r/msg/
  end

  test "nice_error formats different error types" do
    assert CriticalFail.nice_error("oops") == "oops"
    assert CriticalFail.nice_error(:oops) == ":oops"

    changeset = %Ecto.Changeset{
      errors: [email: {"must have %{count} characters", [count: 5]}]
    }

    assert CriticalFail.nice_error(changeset) == "email must have 5 characters"
  end

  test "stacktrace formats and reports exception" do
    {error, trace} =
      try do
        raise "kaboom"
      rescue
        error -> {error, __STACKTRACE__}
      end

    assert capture_log(fn ->
             assert {:error, "Stacktrace in Tester: kaboom"} =
                      CriticalFail.stacktrace("Tester", error, trace, dispatch_id: "abc")
           end) =~ ~r/Stacktrace in Tester: kaboom/
  end

  test "run_unattended_task catches properly" do
    Rivet.Ident.Test.Fixtures.NullTemplate.listen()

    assert capture_log(fn ->
             assert {:error, "Unattended task crashed"} =
                      CriticalFail.run_unattended_task(fn -> raise "task kaboom" end)

             assert_receive {:report_, {"Unattended task crashed", opts}}
             assert %RuntimeError{message: "task kaboom"} = opts[:error]
             assert opts[:traceback] =~ "RuntimeError"
             assert opts[:traceback] =~ "task kaboom"
           end) =~ ~r/Unattended task crashed - level=error/
  end
end
