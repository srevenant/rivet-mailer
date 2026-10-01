defmodule Rivet.Mailer do
  ################################################################################
  # Context
  defmacro __using__(_) do
    quote location: :keep do
      @batch_interval_pending Application.compile_env!(:rivet_mailer, :batch_interval_pending)
      @batch_interval_none Application.compile_env!(:rivet_mailer, :batch_interval_none)
      @send_interval Application.compile_env!(:rivet_mailer, :send_interval)
      @send_timeout Application.compile_env!(:rivet_mailer, :send_timeout)
      @user_model Application.compile_env!(:rivet_mailer, :user_model)
      @email_model Application.compile_env!(:rivet_mailer, :email_model)

      @worker_supervisor :mailer_worker_supervisor

      alias Rivet.Mailer
      alias Rivet.Mailer.{Processor, Dispatch, Target}
      alias Rivet.Mailer.CriticalFail
      # temp
      alias Core.Db.Ident.{User, Email}
      alias Core.Db
      # alias @user_model
      # alias @email_model
    end
  end

  @doc """
  iex> 5000 = getcfg(:batch_size)
  iex> 1 = getcfg(:workers)
  """
  def getcfg(key), do: Application.get_env(:rivet_mailer, key)

  def enabled(bool) when is_boolean(bool),
    do: Application.put_env(:rivet_mailer, :enabled, bool)

  #
  # ################################################################################
  # alias Core.Db
  #
  # use Mailer.Dispatcher,
  #   otp_app: :core,
  #   from_key: [:addrs, :from],
  #   user_model: Db.Ident.User,
  #   email_model: Db.Ident.Email,
  #   allow_recips: :email,
  #   backend: Rivet.Mailer.Rivet.Backend,
  #   configurator: Rivet.Mailer.Rivet.Configurator
end
