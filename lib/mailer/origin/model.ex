defmodule Rivet.Mailer.Origin do
  use TypedEctoSchema
  import Ecto.Changeset
  use Rivet.Ecto.Model
  alias Core.Db

  typed_schema "mailer_origins" do
    belongs_to(:user, Db.Ident.User, type: :binary_id)
    belongs_to(:org, Db.Org, type: :binary_id)
    timestamps()
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    create: [:user_id, :org_id, :id]

  def upsert_origin(%Db.Ident.User{id: user_id}) do
    build(%{user_id})
    |> insert(
      on_conflict: [set: [user_id: user_id]],
      conflict_target: [:user_id],
      returning: [:id]
    )
    |> case do
      {:ok, %__MODULE__{id}} -> {:ok, id}
      # coveralls-ignore-next-line
      error -> error
    end
  end
end
