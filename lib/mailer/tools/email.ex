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
  def expand_emails(%{emails, __struct__: @user_model}) when is_list(emails), do: emails

  def expand_emails(%{__struct__: @user_model} = u),
    do: Mailer.module_for(:user_model).preload!(u, [:emails]).emails

  ##############################################################################
  @doc """
  future: opts can include verfied: true (or some way to only send to verified addresses)
  """
  def get_best_email(%{__struct__: @user_model} = user) do
    with {:ok, %{emails, __struct__: @user_model}} <-
           Mailer.module_for(:user_model).preload(user, [:emails]),
         do: get_best_email_(emails, user)
  end

  def get_best_email(user_id) when is_uuid(user_id) do
    with {:ok, %{emails, __struct__: @user_model} = user} <-
           Mailer.module_for(:user_model).one([id: user_id], [:emails]),
         do: get_best_email_(emails, user)
  end

  def get_best_email_(emails, user) do
    case {Enum.find(emails, fn e -> e.verified end), emails} do
      {%{__struct__: @email_model} = email, _} ->
        {:ok, Map.put(email, :user, user)}

      {_, [email | _]} ->
        {:ok, Map.put(email, :user, user)}

      {_, []} ->
        Logger.error("Cannot get_email for user with no email!", user_id: user.id)
        {:error, "Cannot find email for user"}
    end
  end

  @doc """

  This is split out from mailer_queue_ so it is usable externally without queuing

  This is only for when we don't have email records such as direct
  mailing somebody unknown, or support/internal emails

  eaddr can be a [name, addr] "tuple" (but list because of configs as json),
  or as a single string. Nothing else, as the others should not go direct.

  No lists of emails. Just one.

  iex> direct_email_address(["bob", "bob@blah.com"])
  {:ok, %Rivet.Ident.Email{address: "bob@blah.com"}}

  iex> direct_email_address("bob@blah.com")
  {:ok, %Rivet.Ident.Email{address: "bob@blah.com"}}

  iex> direct_email_address(:sales)
  {:ok, %Rivet.Ident.Email{address: "tardis-support@tardis.net"}}

  iex> direct_email_address(10)
  {:error, "Invalid email address"}
  """

  def direct_email_address([<<_name::binary>>, <<addr::binary>>]),
    do: {:ok, struct(Mailer.module_for(:email_model), %{address: addr})}

  def direct_email_address(<<addr::binary>>),
    do: {:ok, struct(Mailer.module_for(:email_model), %{address: addr})}

  # site email uses atoms; extract with that then process result
  def direct_email_address(key) when is_atom(key),
    do: Mailer.Config.getaddr(key) |> direct_email_address()

  def direct_email_address(_), do: {:error, "Invalid email address"}

  ##############################################################################
  # defp get_email_recip!(%Target{email: %Rivet.Ident.Email{} = e}), do: e
  #
  # # if we got here they either deleted the email from a user OR it is a direct
  # # email; either way just create a mock %Rivet.Ident.Email{} instead.
  # defp get_email_recip!(%Target{address, email_id: nil}), do: %Rivet.Ident.Email{address}
end
