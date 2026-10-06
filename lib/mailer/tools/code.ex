defmodule Rivet.Mailer.Tools.Code do
  use Rivet.Mailer

  def enrich_with_code(user_id, type, meta \\ %{}) do
    lib = Module.concat([@user_code_model, "Lib"])

    with {:ok, code} <- lib.reset_generate(user_id, type, meta) do
      {:ok, Map.put(meta, :code_id, code.id)}
    end
  end

  def code_enrich_assigns(%Dispatch{target, assigns: %{code_id} = assigns} = d) do
    with {:ok, %{user} = code} <- @user_code_model.one([id: code_id], user: [:factors]) do
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
               |> Rivet.Mailer.enrich!(:recip, user)
               |> Rivet.Mailer.enrich!(user)
         }}
      end
    end
  end
end
