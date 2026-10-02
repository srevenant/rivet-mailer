defmodule Test.Support.Mailer.Factories do
  use Test.Support.Mailer.Case.Factory

  use Rivet.Ident.Test.AuthFactory
  use Test.Support.Mailer.Factories.Mailer
end
