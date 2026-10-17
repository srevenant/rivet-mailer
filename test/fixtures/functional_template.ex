defmodule Rivet.Mailer.Test.FunctionalTemplate do
  use Rivet.Mailer.Template

  def queue(target), do: mailer_queue(target)
end
