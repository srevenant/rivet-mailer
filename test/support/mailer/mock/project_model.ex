defmodule Test.Support.Mailer.Mock.ProjectModel do
  # import Ecto.Changeset
  # use Core.ContextClient
  use TypedEctoSchema
  use Rivet.Ecto.Model
  #
  # import DefEnum
  # defenum(Visibility, private: 0, public: 1, closed: 2)
  # defenum(Status, "In Development": 0, "Pre Release": 1, Released: 2)

  ##############################################################################
  typed_schema "projects" do
    # # has_many(:members, Db.Project.Member, on_delete: :delete_all)
    # has_many(:data, Db.Project.Data, on_delete: :delete_all)
    # has_many(:files, Db.File, on_delete: :delete_all, foreign_key: :ref_id)
    # has_many(:tags, Db.TagProject, on_delete: :delete_all)
    # has_many(:invites, Db.Invite, on_delete: :delete_all)
    # has_many(:tallys, Db.Reward.Tally, foreign_key: :project_id)
    # has_one(:journey_actor, Db.Journey.Actor, foreign_key: :ref_id)
    #
    # has_many(:discuss, Db.Project.Discuss, on_delete: :delete_all, foreign_key: :project_id)
    #
    field(:short_id, :string, default: "")
    field(:title, :string, default: "")
    # field(:subtitle, :string, default: "")

    # field(:features, :map, default: %{"newProject" => true})
    # field(:summary, :map, default: %{})
    # field(:license, :map, default: %{})
    # field(:rating, :map, default: %{})
    # field(:website, :string, default: "")
    # field(:visibility, Visibility, default: :private)
    # field(:status, Status, default: :"In Development")
    # field(:format, Format, default: :Novel)
    # field(:released_at, :date)
    # timestamps()
  end

  #

  use Rivet.Ecto.Collection,
    not_found: :atom,
    required: [:title],
    features: [:short_id],
    update: [:title],
    unique: [:title, :short_id]
end
