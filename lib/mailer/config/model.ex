defmodule Rivet.Mailer.Config do
  use TypedEctoSchema
  use Rivet.Ecto.Model
  alias __MODULE__

  typed_schema "mailer_configs" do
    field(:site, :string, default: "")
    field(:group, :string)
    field(:key, :string)
    field(:value, Config.Value)
    timestamps()
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    required: [:group, :key],
    create: [:site],
    update: [:value],
    unique_constraints: [[:site, :group, :key]]

  defdelegate load_site(a), to: Config.Cache
  defdelegate getsite(a), to: Config.Cache
  defdelegate getaddr(a), to: Config.Cache
end
