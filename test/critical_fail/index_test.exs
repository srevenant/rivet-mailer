defmodule Rivet.Mailer.Test.CriticalFail.IndexTest do
  use Rivet.Mailer.Test.Case
  import ExUnit.CaptureLog
  alias Rivet.Mailer.CriticalFail

  test "report_if_error" do
    assert capture_log(fn ->
             assert {:error, "msg", 2} = CriticalFail.report_if_error({:error, "msg", 2})
             assert {:error, _} = CriticalFail.report_if_error({:error, 1})
           end) =~ ~r/msg/
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
    Rivet.Ident.Test.NullTemplate.listen()

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
