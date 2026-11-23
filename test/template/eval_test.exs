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
    assert {:error, "Missing subject or body"} = Eval.eval(@template, "a@b.com", %{})
    assert {:error, "Empty body"} = Eval.eval(@template <> "=== body\n", "a@b.com", %{})

    assert {:ok, %{sections: %{subject: "a@b.com email"}}} =
             Eval.eval(@template <> "=== body\nbody", "a@b.com", %{})

    assert {:error, "Template missing (Narf)"} =
             Eval.generate(%Dispatch{target: %Target{address: "bob"}, template: Narf})

    assert {:error, "Failed to execute" <> _} =
             Eval.eval(
               @template <> "=== body\nsomething <%= for a <- @nope do %>",
               "a@b.com",
               %{}
             )

    assert {:error, "Failed to execute" <> _} =
             Eval.eval(@template <> "=== body\nsomething <%= raise \"nope\" %>", "a@b.com", %{})
  end

  # parsing yaml
  test "rejects metadata that isn't a map" do
    doc = """
    === rivet-engram-v1
    - first
    - second
    === body
    hello
    """

    assert {:error, "Invalid template: Invalid Engram: metadata must be a map"} = Eval.eval(doc, "a@b.c", %{})
  end

  ## not_empty
  test "propagates malformed YAML errors" do
    doc = """
    === rivet-engram-v1
    sections: [unclosed
    === body
    hello
    """

    assert {:error, "Invalid template: Invalid Engram metadata: Unfinished flow collection (line: 1, column: 20)"} =
             Eval.eval(doc, "a@b.c", %{})
  end

  test "handles YAML errors during template evaluation" do
    template = """
    === rivet-engram-v1
    sections:
      subject: eex-yml
      body: eex
    === subject
    <%= "items: [unclosed" %>
    === body
    Hello!
    """

    assert {:error, "Eval error: " <> reason} = Eval.eval(template, "test@example.com", %{})

    assert reason != ""
  end

  test "Eval" do
    template = """
    === rivet-engram-v1
    sections:
      subject: eex-yml
      body: eex
    === subject
    items: 1
    === body
    Hello!
    """

    assert {:error, "Invalid subject as it is not a string"} = Eval.eval(template, "test@example.com", %{})
  end
end
