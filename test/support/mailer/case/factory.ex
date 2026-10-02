defmodule Test.Support.Mailer.Case.Factory do
  defmacro __using__(_) do
    repo = Application.compile_env!(__CALLER__, :rivet, :repo)

    quote location: :keep do
      use Rivet.Mailer
      use ExMachina.Ecto, repo: unquote(repo)
    end
  end
end
