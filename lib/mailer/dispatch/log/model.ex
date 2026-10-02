defmodule Rivet.Mailer.Dispatch.Log do
  use TypedEctoSchema
  use Rivet.Ecto.Model
  use Rivet.Mailer
  import DefEnum
  import CriticalFail, only: [report_if_error: 3]

  defenum(Type,
    pending: 0,
    dispatched: 1,
    # aborted is moved to 200 so we can do < comparisons
    delivered: 3,
    skipped: 4,
    bouncing: 50,
    complaint: 51,
    rejected: 52,

    # ideally we have why it failed ~ bouncing/etc, but sometimes it fails before
    # we even hear dispatch, so this is why failed is here too.
    aborted: 200
  )

  typed_schema "mailer_dispatch_logs" do
    belongs_to(:dispatch, Mailer.Dispatch, type: :binary_id)
    belongs_to(:issue, Email.Issue, type: :binary_id)
    field(:type, Type)
    field(:value, :map)
    timestamps()
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    required: [:dispatch_id, :type],
    # should be one of these two but typically not both
    create: [:issue_id, :value],
    update: []

  def validate_post(chgs),
    do:
      check_constraint(chgs, :issue_id,
        name: :mailer_dispatch_logs_only_one,
        message: "only one of issue_id or value allowed"
      )

  def add(:ses, status, sender_id, %{type, log}) do
    with {:ok, %Mailer.Dispatch{id, target: %Mailer.Target{} = t} = s} <-
           Mailer.Dispatch.get_by_sender_id(sender_id) do
      Mailer.Dispatch.update(s, %{status})
      |> report_if_error("Unable to update Mailer.Dispatch", status: status)

      {:ok, update} = Email.Issue.log(t.email_id, type, log)

      %{type, dispatch_id: id}
      |> Map.merge(update)
      |> create()
      |> report_if_error("Unable to save Mailer.Dispatch.Log",
        dispatch_id: id,
        type: type,
        status: status,
        log: log
      )

      {:ok, id}
    end
  end
end
