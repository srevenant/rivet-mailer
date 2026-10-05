defmodule Rivet.Mailer.Local.Backend do
  use Swoosh.Mailer, otp_app: Application.compile_env!(:rivet_mailer, :otp_app)
end
