defmodule Rivet.Mailer.Template.Queue do
  use Rivet.Mailer

  def mailer_queue_(t, %Email{} = e, assn, opts) do
    with :ok <- valid_target(e, opts), do: Dispatch.queue(e, t, assn)
  end

  def mailer_queue_(t, %{__struct__: @user_model} = u, assn, opts) do
    with {:ok, e} <- Tools.Email.get_best_email(u), do: mailer_queue_(t, e, assn, opts)
  end

  def mailer_queue_(t, other, assn, _opts) do
    with {:ok, %Email{} = e} <- Tools.Email.direct_email_address(other),
         do: Dispatch.queue(e, t, assn)
  end

  ##############################################################################
  def valid_target(%Email{status: status}, opts) do
    cond do
      @email_model.sendable?(status) ->
        :ok

      Keyword.get(opts, :force) ->
        :ok

      true ->
        msg = "Overriding and sending to email address in status=#{status}"
        Logger.error(msg)
        {:error, msg}
    end
  end

  ##############################################################################
  def mailer_queue_all_(t, %{__struct__: @user_model} = u, a), do: mailer_queue_all_(t, [u], a)
  def mailer_queue_all_(t, %Email{} = e, a), do: mailer_queue_all_(t, [e], a)

  def mailer_queue_all_(t, targets, assns),
    do: Mailer.module_for(:repo).transact(fn -> mailer_queue_all_(t, targets, assns, []) end)

  ####
  def mailer_queue_all_(t, [%{__struct__: @user_model} = u | rest], assigns, out) do
    with {:ok, e} <- Tools.Email.get_best_email(u),
         do: mailer_queue_all_(t, [e | rest], assigns, out)
  end

  def mailer_queue_all_(t, [%Email{} = e | rest], assigns, out) do
    with {:ok, d} <- mailer_queue_(t, e, assigns, []),
         do: mailer_queue_all_(t, rest, assigns, [d | out])
  end

  def mailer_queue_all_(_, [], _, out), do: {:ok, Enum.reverse(out)}
end
