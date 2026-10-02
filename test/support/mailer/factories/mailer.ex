defmodule Test.Support.Mailer.Factories.Mailer do
  use Test.Support.Mailer.Case.Factory

  defmacro __using__(_) do
    quote location: :keep do
      import Ecto.Query

      def mailer_dispatch_factory do
        %Dispatch{
          target: build(:mailer_target),
          template: Test.Support.Mailer.Mock.GoodTemplate,
          sender_id: Ecto.UUID.generate(),
          assigns: %{"sonic" => "screwdriver"}
        }
      end

      def mailer_dispatch_log_factory do
        %Dispatch.Log{
          dispatch: build(:mailer_dispatch),
          type: :dispatched,
          value: %{message: "okay"}
        }
      end

      def mailer_target_factory do
        # insert user so we have a uniform UUID
        user = insert(:ident_user)
        email = build(:ident_email, user: user)

        %Target{user, email, address: email.address}
      end

      def mailer_origin_factory do
        # future: org origins
        %Mailer.Origin{user: build(:ident_user)}
      end

      def mailer_sub_factory do
        %Mailer.Sub{
          origin: build(:mailer_origin),
          user: build(:ident_user),
          class: "releases",
          allow: true
        }
      end

      ##########################################################################
      def insert_good_target() do
        email = insert(:ident_email, verified: true)
        t = %{user, email} = insert(:mailer_target, user: email.user, email: email)
        user = shift_user_inserted_at(%{user | emails: [email]})
        %{t | email, user}
      end

      def insert_good_mailer_dispatch(assigns \\ %{}) do
        insert(:mailer_dispatch, target: insert_good_target(), assigns: assigns)
      end

      def insert_dispatched(merge \\ []) do
        target = insert_good_target()
        opts = [target: target, status: :dispatched, sender_id: "ses:#{Ecto.UUID.generate()}"]
        insert(:mailer_dispatch, Keyword.merge(opts, merge))
      end

      defp shift_user_inserted_at(%User{inserted_at: t, id: u_id} = u, minutes \\ -1440) do
        t = DateTime.shift(t, minute: minutes)

        from(u in User, as: :u, where: u.id == ^u_id)
        |> Repo.update_all(set: [inserted_at: t, updated_at: t])
        |> case do
          {1, _} -> %{u | inserted_at: t, updated_at: t}
        end
      end

      ##########################################################################
      defp email_tuple(), do: [Faker.Cat.name(), Faker.Internet.email()]

      # def insert_mailer_site() do
      #   site = insert(:site)
      #
      #   data =
      #     %{
      #       site: %{
      #         name: "#{site.name}",
      #         footer: "a superior footer",
      #         link_api: "https://app.#{site.domain}/v1",
      #         link_app: "https://app.#{site.domain}",
      #         link_home: "https://#{site.domain}"
      #       },
      #       addrs: %{
      #         errors: email_tuple(),
      #         verify: email_tuple(),
      #         from: email_tuple(),
      #         sales: email_tuple(),
      #         support: email_tuple()
      #       }
      #     }
      #     |> Jason.encode!()
      #
      #   # Rivet.Email.Template.create(%{name: "//CONFIG/#{site.domain}", data: data})
      #   site
      # end
      #
      # def insert_site_project() do
      #   site = insert_mailer_site()
      #   %{target: %{email}} = insert_good_mailer_dispatch()
      #   attrs = params_with_assocs(:project) |> Map.put(:site_id, site.id)
      #   {:ok, project} = Core.Db.Project.create(attrs)
      #   pm = insert(:project_member, project: project, user: email.user, roles: [:author])
      #   %{site, email, project}
      # end

      # def make_user_valid(user) do
      #   case Db.Ident.Email.all(user_id: user.id) do
      #     {:ok, [%{verified: true} | _]} -> :ok
      #     {:ok, [%{verified: false} = e | _]} -> Db.Ident.Email.update(e, %{verified: true})
      #     {:ok, []} -> insert(:email, user: user, verified: true)
      #   end
      #
      #   shift_user_inserted_at(user)
      # end
    end
  end
end
