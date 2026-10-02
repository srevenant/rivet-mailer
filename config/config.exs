import Config

config :logger,
  backends: [:console],
  truncate: :infinity,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :logger, :console,
  format: {Rivet.Utils.UniformLogFormat, :format},
  metadata: :all

config :rivet,
  app: :rivet_mailer,
  repo: Test.Support.Mailer.Repo,
  # ecto_repos: [Test.Support.Mailer.Repo],
  user_model: Rivet.Ident.User,
  user_code_model: Rivet.Ident.UserCode,
  email_model: Rivet.Ident.Email,
  org_model: Test.Support.Mailer.Mock.OrgModel,
  project_model: Test.Support.Mailer.Mock.ProjectModel,
  handle_model: Rivet.Ident.Handle,
  mailer_templates: %{
    critical_fail: Rivet.Mailer.CriticalFail
  }

#   system_error: Rivet.Ident.Test.NullTemplate,
#   password_changed: Rivet.Ident.Test.NullTemplate,
#   password_reset: Rivet.Ident.Test.NullTemplate,
#   user_failed_change: Rivet.Ident.Test.NullTemplate,
#   user_verification: Rivet.Ident.Test.NullTemplate
# }

# app: :rivet_ident,
# test: true
# ecto_repos: [Rivet.Test.Repo]
config :rivet_mailer,
  otp_app: :core,
  ecto_repos: [Test.Support.Mailer.Repo],
  # test config things
  mode: :test,
  enricher: Rivet.Mailer.Utils.Enricher,
  # yes this is also available in mailer_templates.critical_fail, but the
  # purposes are different so it needs to be duplicated here, for testing.
  critical_fail: Test.Support.Mailer.Mock.CriticalFail,
  # this is separate from the email enabled flag by design, so processor can
  # run/stop and still the email subsystem can log instead of sending
  enabled: false,
  batch_size: 5_000,
  batch_interval_pending: [10, 100],
  batch_interval_none: [10, 100],
  send_interval: [1, 100],
  send_timeout: 50,
  # how many parallel workers should be running on batches? only increase this
  # if we are falling behind, and be judicious
  workers: 1

config :rivet_mailer, Test.Support.Mailer.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  username: "postgres",
  password: "",
  database: "rivet_mailer_#{config_env()}",
  hostname: "db",
  log: false
