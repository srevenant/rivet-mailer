defmodule Rivet.Mailer.Test.Fixtures.FunctionalTemplate do
  use Rivet.Mailer.Template

  def queue(target), do: mailer_queue(target)
end
