defmodule Rivet.Mailer.Utils.Email do
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
  def expand_emails(%User{emails}) when is_list(emails), do: emails
  def expand_emails(%User{} = u), do: User.preload!(u, [:emails]).emails

  ##############################################################################
  @doc """
  future: opts can include verfied: true (or some way to only send to verified addresses)

  iex> %{user, id: e_id} = insert(:ident_email, verified: true)
  iex> {:ok, %Rivet.Ident.Email{id: ^e_id}} = get_best_email(user)

  iex> get_best_email(insert(:ident_user))
  {:error, "Cannot find email for user"}
  """

  def get_best_email(%User{} = user) do
    with {:ok, %User{emails}} <- User.preload(user, [:emails]),
         do: get_best_email_(emails, user)
  end

  def get_best_email(user_id) when is_uuid(user_id) do
    with {:ok, %User{emails} = user} <- User.one([id: user_id], [:emails]),
         do: get_best_email_(emails, user)
  end

  def get_best_email_(emails, user) do
    case {Enum.find(emails, fn e -> e.verified end), emails} do
      {%Email{} = email, _} ->
        {:ok, %Email{email | user}}

      {_, [email | _]} ->
        {:ok, %Email{email | user}}

      {_, []} ->
        Logger.error("Cannot get_email for user with no email!", user_id: user.id)
        {:error, "Cannot find email for user"}
    end
  end

  @doc """

  This is split out from mailer_queue_ so it is usable externally without queuing

  This is only for when we don't have Email records such as direct
  mailing somebody unknown, or support/internal emails

  eaddr can be a [name, addr] "tuple" (but list because of configs as json),
  or as a single string. Nothing else, as the others should not go direct.

  No lists of emails. Just one.

  iex> direct_email_address(["bob", "bob@blah.com"])
  {:ok, %Email{address: "bob@blah.com"}}

  iex> direct_email_address("bob@blah.com")
  {:ok, %Email{address: "bob@blah.com"}}

  iex> direct_email_address(:sales)
  {:ok, %Email{address: "libreon-support@libreon.net"}}

  iex> direct_email_address(10)
  {:error, "Invalid email address"}
  """

  def direct_email_address([<<_name::binary>>, <<addr::binary>>]),
    do: {:ok, %Email{address: addr}}

  def direct_email_address(<<addr::binary>>), do: {:ok, %Email{address: addr}}

  # site email uses atoms; extract with that then process result
  def direct_email_address(key) when is_atom(key),
    do: Mailer.Config.getaddr(key) |> direct_email_address()

  def direct_email_address(_), do: {:error, "Invalid email address"}

  ##############################################################################
  # defp get_email_recip!(%Target{email: %Email{} = e}), do: e
  #
  # # if we got here they either deleted the %Email from a %User OR it is a direct
  # # email; either way just create a mock %Email{} instead.
  # defp get_email_recip!(%Target{address, email_id: nil}), do: %Email{address}
end
