defmodule Rivet.Mailer.Migrations.Mailer.Base do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS citext")

    ############################################################################
    # a unifying table for targets
    create table(:mailer_targets, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      # NOTE: this is for Dispatches, so while we could bring in email_id through
      # a many:1 join, we already have emails on users for that. This is for a
      # specific purpose of knowing exactly where a given dispatch went. We are
      # not looking for uniqueness on user_id, just the combined set.
      add(:user_id, references(:users, on_delete: :delete_all, type: :uuid), null: true)
      add(:email_id, references(:user_emails, on_delete: :nilify_all, type: :uuid), null: true)

      # for when they don't have a :user/:user_emails record, we still have something to correlate
      add(:address, :citext, null: false)
      timestamps()
    end

    # user can be duplicated as the user can have many email addrs, and :address too
    # create(unique_index(:mailer_targets, [:user_id], where: "user_id IS NOT NULL"))
    create(unique_index(:mailer_targets, [:email_id]))

    # do not create unique for address because conditions could create the same addr across users

    ############################################################################
    create table(:mailer_dispatches, primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(:status, :smallint, default: 0, null: false)

      add(:target_id, references(:mailer_targets, on_delete: :delete_all, type: :uuid),
        null: false
      )

      add(:sender_id, :string)

      add(:lock, :binary_id)
      add(:locked_at, :utc_datetime, null: true)

      add(:template, :string)
      add(:assigns, :map, default: %{}, null: false)

      add(:sent_at, :utc_datetime, null: true)

      timestamps()
    end

    create(index(:mailer_dispatches, [:target_id]))
    create(unique_index(:mailer_dispatches, [:sender_id], where: "sender_id IS NOT NULL"))

    create(
      index(:mailer_dispatches, [:inserted_at, :id],
        where: "status = 0 AND lock IS NULL AND sent_at IS NULL"
      )
    )

    ######################
    create table(:mailer_dispatch_logs, primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(:dispatch_id, references(:mailer_dispatches, on_delete: :delete_all, type: :uuid),
        null: false
      )

      add(:issue_id, references(:user_email_issues, on_delete: :delete_all, type: :uuid),
        null: true
      )

      add(:type, :smallint, null: false)
      add(:value, :map, null: true)
      timestamps()
    end

    create(
      constraint(:mailer_dispatch_logs, :mailer_dispatch_logs_only_one,
        check: "num_nonnulls(issue_id, value) = 1"
      )
    )

    create(index(:mailer_dispatch_logs, [:dispatch_id]))

    ### MOVE TO NOTIFY migration(shutting down)
    # ########################
    # drop_if_exists(table(:notify_email_logs))
    # drop_if_exists(table(:notify_emails))
    # drop_if_exists(table(:notify_messages))
    #
    # flush()
    #
    # # remove this later
    # Rivet.Email.Template.all!()
    # |> Enum.each(fn t ->
    #   name = String.replace(t.name, ".Core.Notify.", ".Core.Mailer.Template.")
    #   {:ok, _} = Rivet.Email.Template.update(t, %{name: name})
    # end)
  end
end
