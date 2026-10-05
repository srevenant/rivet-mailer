defmodule Test.Support.Mailer.Mock.GoodTemplate do
  use Rivet.Mailer
  import Ecto.Query

  def dispatch(%{assigns: %{error: "traceback"}}), do: raise("Traceback")
  def dispatch(%{assigns: %{error: "other"}}), do: {:error, "Woops Error"}
  def dispatch(%{assigns: %{error: "exit"}}), do: exit(:mailer_test_exit)
  def dispatch(%{assigns: %{error: "timeout"}}), do: Process.sleep(5000)

  def dispatch(%{assigns: %{result: "ses"}}),
    do: {:ok, %{id: "ses-test-id", request_id: "request-test-id"}}

  def dispatch(%{assigns: %{error: "error-map"}}), do: {:error, %{reason: "Woops Map"}}

  def dispatch(%{id: id, lock: lock, assigns: %{error: "delete_siblings"}}) do
    # make a problem for our sibling
    from(d in Rivet.Mailer.Dispatch, where: d.lock == ^lock and d.id != ^id)
    |> @repo.delete_all()

    {:ok, "mock template sent"}
  end

  def dispatch(_), do: {:ok, "mock template sent"}
end
