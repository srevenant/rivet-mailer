defmodule Rivet.Mailer.Migrations.Mailer.V03Subscriptions do
  use Ecto.Migration
  use Core.ContextClient

  def change do
    ############################################################################
    # a unifying table for originators
    create table(:mailer_origins, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:user_id, references(:users, on_delete: :delete_all, type: :uuid), null: true)
      # add(:project_id, references(:projects, on_delete: :delete_all, type: :uuid), null: true)
      add(:org_id, references(:orgs, on_delete: :delete_all, type: :uuid), null: true)
      # add(:meet_id, references(:meets, on_delete: :delete_all, type: :uuid), null: true)
      # add(:discuss_id, references(:discuss, on_delete: :delete_all, type: :uuid), null: true)

      timestamps()
    end

    create(unique_index(:mailer_origins, [:user_id]))
    create(unique_index(:mailer_origins, [:org_id]))

    # Exactly one origin
    create(
      constraint(:mailer_origins, :mailer_origins_one_origin,
        check: "num_nonnulls(user_id, org_id) = 1"
      )
    )

    ############################################################################
    create table(:mailer_subs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:allow, :boolean, null: false)

      add(:user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false)

      add(:origin_id, references(:mailer_origins, on_delete: :delete_all, type: :uuid),
        null: false
      )

      # an optional unique key/string specific to the origin, such as for orgs it can be the role within an org like 'admin' or 'member'
      add(:class, :string, null: true)

      timestamps()
    end

    create(unique_index(:mailer_subs, [:user_id, :origin_id, :class]))

    ############################################################################
    # flush()
    #
    # # migrate from prefs to this
    # Core.Db.OotifyUserPref.Lib.migrate()
    #
    # # then drop
    # drop_if_exists(:notify_org_prefs)
    # drop_if_exists(:notify_user_prefs)
    # drop_if_exists(:notify_project_prefs)
  end
end
