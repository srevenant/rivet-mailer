defmodule Test.Support.Mailer.Factories do
  use Test.Support.Mailer.Case.Factory

  use Rivet.Ident.Test.IdentFactory
  use Test.Support.Mailer.Factories.Mailer
end
