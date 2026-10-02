defmodule Rivet.Mailer.Sub do
  use TypedEctoSchema
  use Rivet.Ecto.Model
  use Rivet.Mailer.Db
  use Rivet.Mailer.Template
  use Rivet.Mailer

  typed_schema "mailer_subs" do
    field(:allow, :boolean)
    field(:class, :string)

    belongs_to(:origin, Mailer.Origin, type: :binary_id)
    belongs_to(:user, User, type: :binary_id)

    timestamps()
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    required: [:user_id, :origin_id, :allow, :class],
    # only for migration
    create: [:inserted_at, :updated_at],
    update: [:allow]
end
