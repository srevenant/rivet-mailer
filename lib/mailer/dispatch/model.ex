defmodule Rivet.Mailer.Dispatch do
  use TypedEctoSchema
  import Ecto.Changeset
  use Core.ContextClient
  use Rivet.Ecto.Model
  import EctoEnum
  alias Core.Db.Ident.Email
  alias Rivet.Mailer

  # NOTE: aborted==pre-delivery; failed==after delivery
  defenum(Status, pending: 0, dispatched: 1, aborted: 2, delivered: 3, skipped: 4, failed: 100)

  typed_schema "mailer_dispatches" do
    belongs_to(:target, Mailer.Target, type: :binary_id)
    has_many(:logs, Mailer.Dispatch.Log, foreign_key: :dispatch_id)
    # this is the "latest" of the statuses. see the log for more info on history
    field(:status, Status, default: :pending)
    field(:template, Rivet.Utils.Ecto.Atom)
    field(:assigns, Rivet.Utils.Ecto.AtomKeymap)
    field(:lock, :binary_id)
    field(:locked_at, :utc_datetime)
    field(:sender_id, :string)
    field(:sent_at, :utc_datetime)
    timestamps()

    # virtual fields
    field(:from_key, {:array, :string}, default: ["addrs", "from"], virtual: true)
    field(:config_groups, {:array, :string}, default: nil, virtual: true)
    field(:headers, :map, default: %{}, virtual: true)
    field(:subject, :string, virtual: true)
    field(:body, :string, virtual: true)
    field(:engram, :map, virtual: true)
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    required: [:target_id, :template],
    update: [:sent_at, :status, :assigns, :lock, :locked_at, :sender_id],
    foreign_keys: [:target_id]

  def queue(%Email{address} = e, template, assigns) when not_empty_str(address) do
    with {:ok, target_id} <- Mailer.Target.upsert_email(e),
         do: create(%{template, assigns, target_id, status: :pending})
  end

  def get_by_sender_id(id) when not_empty_str(id) do
    from(n in Mailer.Dispatch, where: n.sender_id == ^id, preload: [:target])
    |> one()
  end
end
