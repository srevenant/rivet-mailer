defmodule Rivet.Mailer.Migrations.Mailer.V05Template do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:mailer_templates, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, default: "")
      add(:data, :text, default: "")
      timestamps()
    end

    create_if_not_exists(unique_index(:mailer_templates, [:name]))
  end
end
