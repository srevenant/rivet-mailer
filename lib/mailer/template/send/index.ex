defmodule Rivet.Mailer.Template.Send do
  use Rivet.Mailer

  ##############################################################################
  def dispatch(%Dispatch{target: %Target{}} = d) do
    with {:ok, %Dispatch{} = d} <- d.template.dispatch_prep(d),
         # context comes after dispatch_prep so prep can set config_groups
         {:ok, %Dispatch{} = d} <- build_context(d),
         {:ok, %Dispatch{} = d} <- Mailer.Template.Eval.generate(d),
         {:ok, %Swoosh.Email{} = e} <- build_email(d),
         do: deliver(e, Application.get_env(:rivet_mailer, :enabled))
  end

  ##############################################################################
  # TODO: migrate/rename "" to "default"
  @configs ["default"]
  defp build_context(%Dispatch{} = d) do
    headers = Map.put(d.headers, "X-Codex-ID", d.id)

    with {:ok, assigns} <- load_assign_configs(d.assigns, d.config_groups || @configs),
         do: {:ok, %{d | headers, assigns}}
  end

  ##############################################################################
  defp deliver(%Swoosh.Email{} = e, true) do
    Logger.debug("Sending email", to: e.to, from: e.from, subject: e.subject)
    Rivet.Mailer.Backend.deliver(e)
  end

  ####
  defp deliver(%Swoosh.Email{} = e, false) do
    Logger.warning("Email disabled, not sending message", to: e.to, from: e.from)

    headers = Enum.map(e.headers, fn {k, v} -> "#{k}: #{v}" end) |> Enum.join("\n")

    Logger.warning("""


    #{headers}
    Subject: #{e.subject}

    --- html

    #{e.html_body}

    --- text

    #{e.text_body}

    """)

    # simulate AWS SES
    {:ok, %{request_id: "email disabled", id: Ecto.UUID.generate()}}
  end

  ##############################################################################
  defp load_assign_configs(assigns, [name | rest]) do
    case Rivet.Mailer.Config.load_site(name) do
      {:ok, assn2} -> merge_assigns(assigns, assn2) |> load_assign_configs(rest)
      # only if there's a DB error, not a missing site
      {:error, e} -> {:error, "Mailer config load error: #{e}"}
    end
  end

  defp load_assign_configs(assigns, []), do: {:ok, assigns}

  ##############################################################################
  # simple deep merge when both keys are dicts; if not right wins
  def merge_assigns(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn
      _, left = %{}, right = %{} -> merge_assigns(left, right)
      _, _left, right -> right
    end)
  end

  ##########################################################################
  def build_email(%Dispatch{target: %Target{address}} = d) when not_empty_str(address) do
    with {:ok, from} <- get_from(d) do
      email = Swoosh.Email.new(to: address, from: from)

      {:ok,
       Enum.reduce(d.headers, email, fn {key, value}, email ->
         Swoosh.Email.header(email, key, value)
       end)
       |> Swoosh.Email.subject(d.subject)
       |> Swoosh.Email.html_body("<html><body>#{d.body}</body></html>")
       |> Swoosh.Email.text_body(Utils.Format.html2text(d.body))}
    end
  end

  defp get_from(%Dispatch{assigns, from_key}) do
    key = Enum.map(from_key, &String.to_existing_atom/1)

    case get_in(assigns, key) do
      [n, e] when not_empty_str(e) -> {:ok, {n, e}}
      e when not_empty_str(e) -> {:ok, e}
      _ -> {:error, "Missing 'from' address in assigns at key #{inspect(key)}"}
    end
  end
end
