defmodule Rivet.Mailer.Template do
  @callback dispatch_prep(Rivet.Mailer.Dispatch.t()) ::
              {:ok, Rivet.Mailer.Dispatch.t()}
              | {:abort, reason :: String.t()}
              | {:error, term()}

  defmacro __using__(_) do
    quote location: :keep do
      # use Rivet.Mailer
      # import Rivet.Guards
      import Rivet.Mailer.Utils.Format
      alias Rivet.Mailer.{Utils, Template, Dispatch}

      @behaviour Template

      def mailer_queue(target, assigns \\ %{}, opts \\ []),
        do: Template.Queue.mailer_queue_(__MODULE__, target, assigns, opts)

      # helper if you want a block of targets at once; no opts passing though
      def mailer_queue_all(targets, a),
        do: Template.Queue.mailer_queue_all_(__MODULE__, targets, a)

      @impl true
      def dispatch_prep(%Dispatch{} = d), do: {:ok, d}
      defoverridable dispatch_prep: 1

      # this exists so we can mock it out for tests and bypass some things
      def dispatch(%Dispatch{template: __MODULE__} = d), do: Template.Send.dispatch(d)
    end
  end

  ##############################################################################

  use TypedEctoSchema
  use Rivet.Ecto.Model
  # use Rivet.Mailer.Db
  # use Rivet.Mailer

  typed_schema "mailer_templates" do
    field(:name, :string)
    field(:data, :string, default: "")
    timestamps()
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    required: [:name],
    update: [:data, :name],
    unique_constraints: [:name]
end
