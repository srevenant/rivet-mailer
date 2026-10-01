defmodule Test.Core.Mailer.Template.EvalTest do
  use Test.Support.Mailer.Case.Mailer
  use Core.ContextClient
  alias Rivet.Mailer.Template.Eval

  # doctest Eval.Helpers, import: true

  @template """
  === rivet-template-v1
  sections:
    subject: eex
    body: eex
  === subject
  <%= @email %> email
  """

  test "process template" do
    assert {:error, "missing subject or body"} = Eval.eval(@template, "a@b.com", %{})
    assert {:error, "empty body"} = Eval.eval(@template <> "=== body\n", "a@b.com", %{})
    assert {:ok, "a@b.com email", _} = Eval.eval(@template <> "=== body\nbody", "a@b.com", %{})

    assert {:error, "template missing (Narf)"} =
             Eval.generate(%Dispatch{target: %Target{address: "bob"}, template: Narf})
  end
end
