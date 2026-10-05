defmodule Rivet.Mailer.Local.Enrich do
  @moduledoc """
  This is for runtime assigns enrichment when templates run, and can be
  overridden locally to customize it.
  """
  use Rivet.Mailer

  # top level
  @callback enrich!(assigns :: map(), User.t()) :: map()
  # under key
  @callback enrich!(assigns :: map(), key :: atom(), User.t()) :: map()

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

  # ##############################################################################
  # def get_user_ref!(user, preload \\ nil)
  # def get_user_ref!(%User{handle: %Handle{handle: handle}}, _), do: handle
  #
  # def get_user_ref!(%User{} = user, :preload) do
  #   with {:ok, user} <- User.preload(user, [:handle]), do: get_user_ref!(user, nil)
  # end
  #
  # def get_user_ref!(%User{id: id}, nil), do: id
  #
  # # # nothing we can do; probably a direct email
  # # def get_user_ref!(nil, nil), do: nil
  #
  # ##############################################################################
  # def frontend(path), do: "#{getsite(:link_front)}#{path}"

  # def get_link!(%Db.Project{short_id}), do: frontend("/p/#{short_id}")
  # def get_link!(%{project: %Db.Project{} = p}), do: get_link!(p)
  # def get_link!(%Db.Org{} = o), do: get_link!(o)
  # def get_link!(%{org: %Db.Org{} = o}), do: get_link!(o)
  # def get_link!(%Db.Invite{} = i), do: frontend("/invite/#{String.upcase(i.short_id)}")
  #
  # def get_link_journey!(%Db.Project{} = p), do: "#{get_link!(p)}/e/journey"
  #
  # def get_link_challenge_input_group!(%Db.Project{} = p),
  #   do: "#{get_link!(p)}/e/inputs"
  #
  # def get_link_member_manage!(x), do: "#{get_link!(x)}/members"
  # def get_link_user!(handle), do: frontend("/u/#{handle}")
  # def get_link_user_profile!(handle), do: frontend("/u/#{handle}/profile")
  # def get_link_user_contact!(handle), do: frontend("/u/#{handle}/contact")
  # def get_link_user_subs!(handle), do: frontend("/u/#{handle}/subscriptions")
  # def get_link_user_delete!(handle), do: frontend("/u/#{handle}/delete")
  #
  # def get_link_journey_map!(p, %Db.Journey.Actor.Journey{} = jam),
  #   do: "#{get_link_challenge_input_group!(p)}/#{String.slice(jam.id, 0..4//1)}"
  #
  # def get_link_journey_answer!(p, jmap, rub_id, link_id) do
  #   rub_id = String.slice(rub_id, 0..2//1)
  #   link_id = String.slice(link_id, 0..2//1)
  #   "#{get_link_journey_map!(p, jmap)}?r=#{rub_id}&q=#{link_id}"
  # end
  #
  # def get_link_mentor_answer!(a_id), do: frontend("/c/mentor/#{a_id}")
  #
  # def get_link_sign_on!(), do: frontend("/auth/signon")
  # def get_link_user_pwreset!(_handle), do: frontend("/auth/password")
  #
  # ##############################################################################
  # @enrich Application.compile_env(:rivet_mailer, :enrich_callback, fn a, _ -> a end)
  #
  # def enrich_links!(assigns, %User{} = user) do
  #   @enrich.(assigns, user)
  # handle = get_user_ref!(user, :preload)
  #
  # links = %{
  #   profile: get_link_user_profile!(handle),
  #   subs: get_link_user_subs!(handle),
  #   contact: get_link_user_contact!(handle),
  #   delete: get_link_user_delete!(handle),
  #   pwreset: get_link_user_pwreset!(handle)
  # }
  #
  # Map.update(assigns, :links, links, fn current -> Map.merge(current, links) end)
  # end
  #
  # ##############################################################################
  # def enrich_invite!(assigns, %Db.Invite{project: %Db.Project{} = p} = i),
  #   do: enrich_invite_!(assigns, p.title, p, i)
  #
  # def enrich_invite!(assigns, %Db.Invite{org: %Db.Org{} = o} = i),
  #   do: enrich_invite_!(assigns, o.name, o, i)
  #
  # defp enrich_invite_!(assigns, to_name, to, invite),
  #   do:
  #     Map.put(assigns, :invite, %{
  #       to: to_name,
  #       to_link: get_link!(to),
  #       link: get_link!(invite),
  #       manage_link: get_link_member_manage!(to)
  #     })
  #
  # #########
  # def enrich_org!(assigns, %{org: %Db.Org{} = org}),
  #   do: enrich_org!(assigns, org)
  #
  # def enrich_org!(assigns, %Db.Org{} = org) do
  #   Map.put(assigns, :org, org)
  #   |> merge_links(%{
  #     org: get_link!(org)
  #   })
  # end
  #
  # def enrich_project!(assigns, %Db.Project{} = project) do
  #   Map.put(assigns, :project, project)
  #   |> merge_links(%{
  #     project: get_link!(project),
  #     journey: get_link_journey!(project)
  #   })
  # end
  #
  # defp merge_links(assigns, links),
  #   do: Map.update(assigns, :links, links, fn current -> Map.merge(current, links) end)
  #
  # def enrich_user!(assigns, key, user) do
  #   Map.put(assigns, key, %{
  #     handle: get_user_ref!(user),
  #     name: Rivet.Mailer.Tools.Format.human_name(user),
  #     hello: Rivet.Mailer.Tools.Format.human_name(user, prefix: "Hello", noname: "Hello"),
  #     user: user
  #   })
  # end
end
