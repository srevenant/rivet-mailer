defmodule Rivet.Mailer.Test.IndexTest do
  use Rivet.Mailer.Test.Case

  doctest Rivet.Mailer, import: true
  test "enrich" do
    assert %{a: 1} == Rivet.Mailer.enrich!(%{a: 1}, nil, nil)
    assert %{a: 1} == Rivet.Mailer.enrich!(%{a: 1}, nil)
  end
end
