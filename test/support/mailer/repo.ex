defmodule Test.Support.Mailer.Repo do
  @moduledoc false
  use Ecto.Repo, otp_app: :rivet_mailer, adapter: Ecto.Adapters.Postgres
end
