defmodule Test.Mailer.Template.IndexTest do
  use Test.Support.Mailer.Case

  doctest Mailer.Template, import: true

  alias Test.Support.Mailer.FunctionalTemplate

  test "FunctionalTemplate" do
    %{user} = insert(:ident_handle)
    insert(:ident_email, user: user)

    expect_queue(FunctionalTemplate, [user], ~r/had its password changed/)
  end
end
