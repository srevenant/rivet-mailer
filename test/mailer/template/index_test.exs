defmodule Test.Core.Mailer.Template.IndexTest do
  use Test.Support.Mailer.Case.Mailer
  use Core.ContextClient

  doctest Mailer.Template, import: true
end
