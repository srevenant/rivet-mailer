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
  repo: Rivet.Mailer.Test.Repo,
  user_model: Rivet.Ident.User,
  user_code_model: Rivet.Ident.User.Code,
  email_model: Rivet.Ident.Email,
  email_issue_model: Rivet.Ident.Email.Issue,
  org_model: Rivet.Mailer.Test.Fixtures.OrgModel,
  project_model: Rivet.Mailer.Test.Fixtures.ProjectModel,
  handle_model: Rivet.Ident.Handle,
  mailer_templates: %{
    critical_fail: Rivet.Mailer.CriticalFail
  }

config :rivet_ident,
  defenums: [
    {Rivet.Ident.Access.Domains, global: 0},
    {Rivet.Ident.Email.Status, pending: 0, verified: 1, bouncing: 2, complaint: 3, rejected: 4},
    {Rivet.Ident.User.Code.Types, password_reset: 0, email_verify: 1, delete_request: 3},
    {Rivet.Ident.User.Data.Types, address: 2, profile: 4, toggles: 5, save: 6, social: 20}
  ]

# app: :rivet_ident,
# test: true
# ecto_repos: [Rivet.Test.Repo]
config :rivet_mailer,
  # for swoosh
  otp_app: :rivet_mailer,
  ecto_repos: [Rivet.Mailer.Test.Repo],
  # test config things
  mode: :test,
  local_enrich: Rivet.Mailer.Test.Enrich,
  # yes this is also available in mailer_templates.critical_fail, but the
  # purposes are different so it needs to be duplicated here, for testing.
  critical_fail: Rivet.Ident.Test.Fixtures.NullTemplate,
  # this is separate from the email enabled flag by design, so processor can
  # run/stop and still the email subsystem can log instead of sending
  password_history: 6,
  enabled: false,
  batch_size: 5_000,
  batch_interval_pending: [10, 100],
  batch_interval_none: [10, 100],
  send_interval: [1, 100],
  send_timeout: 50,
  # how many parallel workers should be running on batches? only increase this
  # if we are falling behind, and be judicious
  workers: 1

config :rivet_mailer, Rivet.Mailer.Test.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  username: "postgres",
  password: "",
  database: "rivet_mailer_#{config_env()}",
  hostname: "db",
  log: false
