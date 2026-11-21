defmodule Rivet.Mailer.Test.Tools.IndexTest do
  use Rivet.Mailer.Test.Case
  use Rivet.Mailer
  import Rivet.Mailer.Tools.Email

  doctest Rivet.Mailer.Tools.Email, import: true

  test "get_best_email" do
    assert %{user, id: e_id} = insert(:ident_email, verified: true)
    assert {:ok, %@email_model{id: ^e_id}} = get_best_email(user)
    assert {:ok, %@email_model{id: ^e_id}} = load_user_email(user.id)

    ExUnit.CaptureLog.capture_log(fn ->
      u = insert(:ident_user)
      assert {:error, "Cannot find email for user"} = get_best_email(u.id)
    end)
  end

  alias Rivet.Mailer.Tools.Format

  test "human_name" do
    id = Ecto.UUID.generate()
    opts = %{prefix: "blue", suffix: "bork"}
    handle = %Rivet.Ident.Handle{id, handle: "Narf"}
    u = %Rivet.Ident.User{id, handle, name: ""}

    assert "blue Narf bork" = Format.human_name(u, opts)

    assert "noname" =
             Format.human_name(%{u | handle: %{handle | handle: ""}}, %{noname: "noname"})

    assert "blue boop bork" = Format.human_name(%{u | name: "boop"}, opts)
  end

  test "html2text" do
    expected = """
    **an html doc**

    Header
    ======

    more

    with

    * list

    breaks
    """

    source = """
    <b>an html doc</b><h1>Header</h1>more<p>with<ul><li>list</li></ul>breaks
    """

    assert String.trim(expected) == Format.html2text(source)
  end
end
