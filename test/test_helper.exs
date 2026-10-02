Faker.start()

repo = Test.Support.Mailer.Repo

Supervisor.start_link(
  [
    repo,
    Rivet.Mailer.Config.Cache,
    # Rivet.Auth.Cache,
    # Rivet.Ident.Factor.Cache,
    {Task.Supervisor, name: :mailer_worker_supervisor}
    # Rivet.Mailer.Processor
  ],
  strategy: :one_for_one,
  name: Test.Support.Supervisor
)

:ok =
  Rivet.Loader.Updates.load_for_logged(repo,
    limits: %{env: "test", release_app: "rivet_mailer"},
    load_prefixes: ["Rivet.Mailer"]
  )

ExUnit.configure(formatters: [ExUnit.CLIFormatter])
ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
