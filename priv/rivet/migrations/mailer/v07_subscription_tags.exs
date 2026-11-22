defmodule Rivet.Mailer.Migrations.Mailer.V07SubscriptionTags do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:mailer_subs) do
      add(:tags, {:array, :"varchar(32)"}, null: false, default_value: [])
    end
  end
end
