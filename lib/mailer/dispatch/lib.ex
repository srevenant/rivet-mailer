defmodule Rivet.Mailer.Dispatch.Lib do
  use Rivet.Mailer.Db
  use Rivet.Mailer

  # @doc """
  # iex> lock = Ecto.UUID.generate()
  # iex> insert(:mailer_dispatch, lock: lock)
  # iex> unlock(lock)
  # {1, nil}
  # """
  # def unlock(lockname) do
  #   from(n in Mailer.Dispatch, where: n.lock == ^lockname)
  #   |> Repo.update_all(set: [lock: nil])
  # end

  ##############################################################################
  defp batch_base_query(),
    do:
      from(
        s in Dispatch,
        where: s.status == :pending and is_nil(s.lock) and is_nil(s.sent_at)
      )

  defp pending(), do: from(s in batch_base_query(), select: s.id)

  def count_pending(), do: pending() |> Repo.aggregate(:count)

  @doc """
  iex> insert(:mailer_dispatch)
  iex> {:ok, _lock, _count, _ids} = get_batch(10)
  iex> :none = get_batch(10)
  """
  def get_batch(batch_size) do
    lock = Ecto.UUID.generate()
    now = DateTime.utc_now()

    picked =
      from(s in batch_base_query(),
        order_by: [asc: s.inserted_at, asc: s.id],
        limit: ^batch_size,
        lock: "FOR UPDATE SKIP LOCKED",
        select: s.id
      )

    from(s in Dispatch,
      # done as a subquery because PostgreSQL does not support ORDER BY or LIMIT
      # directly on an UPDATE; this gives us both in one query.
      where: s.id in subquery(picked),
      select: s.id
    )
    |> Repo.update_all(set: [lock: lock, locked_at: now, updated_at: now])
    |> case do
      {count, [_ | _] = ids} when count > 0 ->
        {:ok, lock, count, ids}

      {0, []} ->
        :none
    end
  rescue
    # coveralls-ignore-next-line
    err -> {:error, err}
  end

  ## diag/debug/cleanup things
  # def remove_old() do
  #   now = DateTime.utc_now() |> DateTime.shift(month: -3)
  #
  #   from(n in Dispatch, where: not is_nil(n.sent_at) and n.sent_at < ^now)
  #   |> Repo.delete_all()
  #
  #   # from(n in Dispatch, where: not not is_nil(n.sent_at) and n.updated_at < ^now)
  #   # |> Repo.aggregate(:count)
  # end
  #
  # def export_templates(fname) do
  #   File.write(fname, "---\ntype: Rivet.Data\nversion: 2.1\n\n")
  #
  #   Rivet.Mailer.Template.all!([], order_by: [:name])
  #   |> Enum.each(fn t ->
  #     doc =
  #       Ymlr.documents!([
  #         %{
  #           type: "Rivet.Mailer.Template",
  #           values: %{
  #             id: t.id,
  #             name: "#{t.name}",
  #             data: t.data
  #           }
  #         }
  #       ])
  #
  #     File.write(fname, doc, [:append])
  #     File.write(fname, "\n", [:append])
  #   end)
  # end

  ##############################################################################
  # dangerous, only for tests
  # coveralls-ignore-start
  if Application.compile_env(:rivet_mailer, :mode) == :test do
    def test_clear_pending(),
      do: pending() |> Repo.update_all(set: [sent_at: DateTime.utc_now(), lock: nil])
  end

  # coveralls-ignore-stop
end
