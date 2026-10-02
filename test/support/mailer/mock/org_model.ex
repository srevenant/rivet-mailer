defmodule Test.Support.Mailer.Mock.OrgModel do
  # import Ecto.Changeset
  # use Core.ContextClient
  use TypedEctoSchema
  use Rivet.Ecto.Model
  import DefEnum

  defenum(Status, inserted: 0, registered: 1, closed: 2)
  defenum(Type, tbd: 0, provider: 1, house: 2)

  typed_schema "orgs" do
    # belongs_to(:site, Db.Site, type: :binary_id)
    field(:name, :string)
    field(:short_id, :string, default: "")
    field(:status, Status, default: :inserted)
    field(:type, Type, default: :provider)
    field(:summary, :map, default: %{})
    field(:style, :map, default: %{})
    field(:license, :map, default: %{})
    # has_many(:tallys, Db.Reward.Tally, foreign_key: :org_id)
    # has_many(:invites, Db.Invite, on_delete: :delete_all)
    # has_many(:files, Db.File, on_delete: :delete_all, foreign_key: :ref_id)
    # has_many(:members, Db.Org.Member, on_delete: :delete_all)
    # has_many(:data, Db.Org.Data, on_delete: :delete_all)
    # has_many(:tags, Db.TagOrg, on_delete: :delete_all)
    timestamps()
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    required: [:name],
    features: [:short_id],
    update: [:name, :short_id, :status, :type, :style, :license, :summary],
    unique: [:name]
end
