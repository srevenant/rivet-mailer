defmodule Rivet.Mailer.Test.Template.EvalTest do
  use Rivet.Mailer.Test.Case
  alias Rivet.Mailer.Template.Eval

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

    assert {:ok, %{sections: %{subject: "a@b.com email"}}} =
             Eval.eval(@template <> "=== body\nbody", "a@b.com", %{})

    assert {:error, "template missing (Narf)"} =
             Eval.generate(%Dispatch{target: %Target{address: "bob"}, template: Narf})

    assert {:error, "Failed to execute" <> _} = Eval.eval(@template <> "=== body\nsomething <%= for a <- @nope do %>", "a@b.com", %{})
    assert {:error, "Failed to execute" <> _} = Eval.eval(@template <> "=== body\nsomething <%= raise \"nope\" %>", "a@b.com", %{})
  end
end
