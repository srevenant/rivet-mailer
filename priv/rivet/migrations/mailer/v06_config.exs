defmodule Rivet.Mailer.Migrations.Mailer.V06Config do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:mailer_configs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:site, :string, null: false)
      add(:group, :string, null: false)
      add(:key, :string, null: false)
      add(:value, :map, null: false)
      timestamps()
    end

    create(unique_index(:mailer_configs, [:site, :group, :key]))

    # flush()
    # execute("INSERT INTO mailer_configs SELECT * FROM email_configs;")
    # execute("UPDATE mailer_configs set site = 'default' where site = ''")
  end
end
