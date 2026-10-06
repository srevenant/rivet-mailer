defmodule Rivet.Mailer do
  ################################################################################
  # Context
  defmacro __using__(_) do
    quote location: :keep do
      @user_model Application.compile_env!(:rivet, :user_model)
      @user_code_model Application.compile_env!(:rivet, :user_code_model)
      @email_model Application.compile_env!(:rivet, :email_model)
      @email_issue_model Application.compile_env!(:rivet, :email_issue_model)
      @org_model Application.compile_env!(:rivet, :org_model)
      @handle_model Application.compile_env!(:rivet, :handle_model)
      @repo Application.compile_env!(:rivet, :repo)

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

  def enrich!(a, k, t), do: module_for(:local_enrich).enrich!(a, k, t)
  def enrich!(a, t), do: module_for(:local_enrich).enrich!(a, t)

  def enabled(bool) when is_boolean(bool),
    do: Application.put_env(:rivet_mailer, :enabled, bool)

  def module_for(name), do: Application.fetch_env!(:rivet, name)

  IO.puts("\n[Rivet.Mailer] Ecto may report invalid association warnings for consumer-provided schemas during compilation. These warnings are expected and can be ignored.\n")
end
