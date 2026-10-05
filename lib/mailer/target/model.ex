defmodule Rivet.Mailer.Target do
  use TypedEctoSchema
  use Rivet.Ecto.Model
  use Rivet.Mailer.Db
  use Rivet.Mailer.Template
  use Rivet.Mailer

  typed_schema "mailer_targets" do
    # NOTE: this is for Dispatches, so while we could bring in email_id through
    # a many:1 join, we already have emails on users for that. This is for a
    # specific purpose of knowing exactly where a given dispatch went. We are
    # not looking for uniqueness on user_id, just the combined set.
    belongs_to(:user, @user_model, type: :binary_id)
    belongs_to(:email, @email_model, type: :binary_id)
    field(:address, :string)
    timestamps()
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    required: [:address],
    update: [:email_id, :user_id, :address]

  # direct email with no internal user/email records
  def upsert_email(%Email{address, user_id: nil}) when not_empty_str(address) do
    with {:ok, %__MODULE__{id: target_id}} <- create(%{address}), do: {:ok, target_id}
  end

  # or a send with actual user/email relations
  def upsert_email(%Email{user_id, address, id: email_id})
      when is_uuid(user_id) and is_uuid(email_id) do
    # fugly so it happens in one movement
    build(%{email_id, user_id, address})
    |> insert(
      # while this could be :nothing, by making it :set the returning: [:id]
      # works for both scenarios (existing or not)
      on_conflict: [set: [email_id: email_id]],
      conflict_target: [:email_id],
      returning: [:id]
    )
    |> case do
      {:ok, %__MODULE__{id}} -> {:ok, id}
      # coveralls-ignore-next-line
      error -> error
    end
  end

  # def get_by_email_id(email_id) when is_uuid(email_id) do
  #   from(t in __MODULE__, where: t.email_id == ^email_id, select: t.id)
  #   |> one()
  # end
end
