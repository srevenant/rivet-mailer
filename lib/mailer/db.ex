defmodule Rivet.Mailer.Db do
  defmacro __using__(_) do
    quote do
      alias Ecto.Changeset
      alias Rivet.Mailer.CriticalFail
      use Ecto.Schema

      # import Ecto, only: [assoc: 2]
      import Ecto.Changeset
      import Ecto.Query

      @timestamps_opts [type: :utc_datetime]
    end
  end
end
