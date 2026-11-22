defmodule Rivet.Mailer.Sub do
  use TypedEctoSchema
  use Rivet.Ecto.Model
  use Rivet.Mailer.Db
  use Rivet.Mailer.Template
  use Rivet.Mailer

  typed_schema "mailer_subs" do
    field(:allow, :boolean)
    field(:class, :string)
    field(:tags, {:array, :string}, default: [])

    belongs_to(:origin, Mailer.Origin, type: :binary_id)
    belongs_to(:user, @user_model, type: :binary_id)

    timestamps()
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    required: [:user_id, :origin_id, :allow, :class],
    # only for migration
    create: [:inserted_at, :updated_at],
    update: [:allow, :tags]

  # todo: unsub/sub variant
  def subscribe(user_id, origin_id, class) do
    keys = [user_id: user_id, origin_id: origin_id, class: class]

    case one(keys) do
      {:ok, %{allow: true}} = pass -> pass
      {:ok, %{allow: false} = sub} -> Mailer.Sub.update(sub, %{allow: true})
      {:error, :not_found} -> Mailer.Sub.create(Map.new(keys ++ [allow: true]))
      # coveralls-ignore-next-line
      {:error, _} = pass -> pass
    end
  end
end
