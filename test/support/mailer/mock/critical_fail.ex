defmodule Test.Support.Mailer.Mock.CriticalFail do
  require Logger

  def report_(log, info) do
    Logger.error(log, info)
    {:error, log}
  end
end
