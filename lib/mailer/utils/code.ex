defmodule Rivet.Mailer.Utils.Code do
  require Logger
  use Rivet.Mailer
  alias Core.Db.Ident.UserCode
  import Rivet.Mailer.Utils.Constants, only: [enrich_user!: 3, enrich_links!: 2]

  def enrich_with_code(user_id, type, meta \\ %{}) do
    with {:ok, code} <- UserCode.Lib.reset_generate(user_id, type, meta) do
      {:ok, Map.put(meta, :code_id, code.id)}
    end
  end

  def code_enrich_assigns(%Dispatch{target, assigns: %{code_id} = assigns} = d) do
    with {:ok, %{user} = code} <- UserCode.one([id: code_id], user: [:factors]) do
      expires = Rivet.Utils.Time.ago(code.expires, format: :long)

      if user.id != target.user_id do
        {:abort, "email user does not match code user"}
      else
        {:ok,
         %{
           d
           | assigns:
               Map.merge(assigns, %{
                 expires,
                 code: code.code,
                 nfactors: length(user.factors)
               })
               |> enrich_user!(:recip, user)
               |> enrich_links!(user)
         }}
      end
    end
  end
end
