defmodule Rivet.Mailer.Test.Template.IndexTest do
  use Rivet.Mailer.Test.Case

  doctest Mailer.Template, import: true

  alias Test.Support.Mailer.FunctionalTemplate

  test "FunctionalTemplate" do
    %{user} = insert(:ident_handle)
    insert(:ident_email, user: user)

    expect_queue(FunctionalTemplate, [user], ~r/had its password changed/)
  end
end
