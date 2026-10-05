defmodule Test.Mailer.IndexTest do
  use Test.Support.Mailer.Case

  test "enrich" do
    assert %{a: 1} == Rivet.Mailer.enrich!(%{a: 1}, nil, nil)
    assert %{a: 1} == Rivet.Mailer.enrich!(%{a: 1}, nil)
  end
end
