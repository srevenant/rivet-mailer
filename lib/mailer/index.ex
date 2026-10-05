defmodule Rivet.Mailer do
  ################################################################################
  # Context
  defmacro __using__(_) do
    user_model = Application.compile_env!(__CALLER__, :rivet, :user_model)
    user_code_model = Application.compile_env!(__CALLER__, :rivet, :user_code_model)
    email_model = Application.compile_env!(__CALLER__, :rivet, :email_model)
    org_model = Application.compile_env!(__CALLER__, :rivet, :org_model)
    handle_model = Application.compile_env!(__CALLER__, :rivet, :handle_model)
    repo = Application.compile_env!(__CALLER__, :rivet, :repo)

    quote location: :keep do
      alias unquote(user_model), as: User
      alias unquote(user_code_model), as: UserCode
      alias unquote(email_model), as: Email
      alias unquote(org_model), as: Org
      alias unquote(handle_model), as: Handle
      alias unquote(repo), as: Repo

      @batch_interval_pending Application.compile_env!(:rivet_mailer, :batch_interval_pending)
      @batch_interval_none Application.compile_env!(:rivet_mailer, :batch_interval_none)
      @send_interval Application.compile_env!(:rivet_mailer, :send_interval)
      @send_timeout Application.compile_env!(:rivet_mailer, :send_timeout)

      @worker_supervisor :mailer_worker_supervisor

      require Logger
      import Rivet.Guards
      alias Rivet.Mailer
      alias Rivet.Mailer.{Processor, Dispatch, Target, Tools}
      alias Rivet.Mailer.CriticalFail
    end
  end

  @doc """
  iex> 5000 = getcfg(:batch_size)
  iex> 1 = getcfg(:workers)
  """
  def getcfg(key), do: Application.get_env(:rivet_mailer, key)

  @enricher Application.compile_env!(:rivet_mailer, :enricher)
  def enrich!(a, k, t), do: @enricher.enrich!(a, k, t)
  def enrich!(a, t), do: @enricher.enrich!(a, t)

  def enabled(bool) when is_boolean(bool),
    do: Application.put_env(:rivet_mailer, :enabled, bool)
end
