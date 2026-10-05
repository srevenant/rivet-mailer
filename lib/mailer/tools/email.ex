defmodule Rivet.Mailer.Tools.Email do
  use Rivet.Mailer

  ##############################################################################
  @doc """
  iex> %{user} = e = insert(:ident_email, verified: true)
  iex> e = Ecto.reset_fields(e, [:user])
  iex> expand_emails(%{user | emails: [e]})
  [e]
  iex> expand_emails(user)
  [e]
  """
  def expand_emails(%@user_model{emails}) when is_list(emails), do: emails
  def expand_emails(%@user_model{} = u), do: @user_model.preload!(u, [:emails]).emails

  ##############################################################################
  @doc """
  future: opts can include verfied: true (or some way to only send to verified addresses)
  """
  def get_best_email(%@user_model{} = user) do
    with {:ok, %@user_model{emails}} <- @user_model.preload(user, [:emails]),
         do: get_best_email_(emails, user)
  end

  def get_best_email(user_id) when is_uuid(user_id) do
    with {:ok, %@user_model{emails} = user} <- @user_model.one([id: user_id], [:emails]),
         do: get_best_email_(emails, user)
  end

  def get_best_email_(emails, user) do
    case {Enum.find(emails, fn e -> e.verified end), emails} do
      {%@email_model{} = email, _} ->
        {:ok, %@email_model{email | user}}

      {_, [email | _]} ->
        {:ok, %@email_model{email | user}}

      {_, []} ->
        Logger.error("Cannot get_email for user with no email!", user_id: user.id)
        {:error, "Cannot find email for user"}
    end
  end

  @doc """

  This is split out from mailer_queue_ so it is usable externally without queuing

  This is only for when we don't have @email_model records such as direct
  mailing somebody unknown, or support/internal emails

  eaddr can be a [name, addr] "tuple" (but list because of configs as json),
  or as a single string. Nothing else, as the others should not go direct.

  No lists of emails. Just one.

  iex> direct_email_address(["bob", "bob@blah.com"])
  {:ok, %@email_model{address: "bob@blah.com"}}

  iex> direct_email_address("bob@blah.com")
  {:ok, %@email_model{address: "bob@blah.com"}}

  iex> direct_email_address(:sales)
  {:ok, %@email_model{address: "tardis-support@tardis.net"}}

  iex> direct_email_address(10)
  {:error, "Invalid email address"}
  """

  def direct_email_address([<<_name::binary>>, <<addr::binary>>]),
    do: {:ok, %@email_model{address: addr}}

  def direct_email_address(<<addr::binary>>), do: {:ok, %@email_model{address: addr}}

  # site email uses atoms; extract with that then process result
  def direct_email_address(key) when is_atom(key),
    do: Mailer.Config.getaddr(key) |> direct_email_address()

  def direct_email_address(_), do: {:error, "Invalid email address"}

  ##############################################################################
  # defp get_email_recip!(%Target{email: %@email_model{} = e}), do: e
  #
  # # if we got here they either deleted the %@email_model from a %@user_model OR it is a direct
  # # email; either way just create a mock %@email_model{} instead.
  # defp get_email_recip!(%Target{address, email_id: nil}), do: %@email_model{address}
end
