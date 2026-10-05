defmodule Rivet.Mailer.Local.Enrich do
  @moduledoc """
  This is for runtime assigns enrichment when templates run, and can be
  overridden locally to customize it.
  """
  use Rivet.Mailer

  # top level
  @callback enrich!(assigns :: map(), @user_model.t()) :: map()
  # under key
  @callback enrich!(assigns :: map(), key :: atom(), @user_model.t()) :: map()

  defmacro __using__(_) do
    quote location: :keep do
      @doc """
      enrich target based on its type and add enriched values into assigns
      """
      @behaviour Rivet.Mailer.Local.Enrich
      def enrich!(assigns, _target), do: assigns
      defoverridable enrich!: 2

      @doc """
      enrich target based on its type and add enriched values into assigns under key
      """
      @behaviour Rivet.Mailer.Local.Enrich
      def enrich!(assigns, _key, _target), do: assigns
      defoverridable enrich!: 3
    end
  end

  # defaults for when unconfigured
  def enrich!(assigns, _target), do: assigns
  def enrich!(assigns, _key, _target), do: assigns
end
