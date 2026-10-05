defmodule Rivet.Mailer.Origin do
  use TypedEctoSchema
  use Rivet.Ecto.Model
  use Rivet.Mailer.Db
  use Rivet.Mailer.Template
  use Rivet.Mailer

  typed_schema "mailer_origins" do
    belongs_to(:user, @user_model, type: :binary_id)
    # belongs_to(:org, Org, type: :binary_id)
    timestamps()
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    create: [:user_id, :id]

  def upsert_origin(%@user_model{id: user_id}) do
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
