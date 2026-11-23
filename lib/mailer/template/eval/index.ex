defmodule Rivet.Mailer.Template.Eval do
  use Rivet.Mailer
  alias Rivet.Engram

  def generate(%Dispatch{target: %Target{address}} = d) when not_empty_str(address) do
    case Rivet.Mailer.Template.one(name: to_string(d.template)) do
      {:ok, tdata} ->
        with {:ok, %Engram{sections: %{subject, body}} = engram} <-
               eval(tdata.data, address, d.assigns),
             do: {:ok, %{d | subject, body, engram}}

      {:error, :not_found} ->
        {:error, "Template missing (#{inspect(d.template)})"}
    end
  end

  def eval(template, recip, assigns) do
    assigns = Map.put(assigns, :email, recip)

    # future: perhaps imports in template or opts somehow
    imports = []

    case Rivet.Engram.process_string(template, assigns: assigns, imports: imports) do
      {:ok, %Rivet.Engram{sections: %{subject, body}} = en} ->
        with {:ok, subject} <- not_empty(subject, "subject"),
             {:ok, body} <- not_empty(body, "body"),
             do: {:ok, %{en | sections: %{en.sections | subject, body}}}

      {:ok, _} ->
        {:error, "Missing subject or body"}

      {:error, {:parse, reason}} ->
        {:error, "Invalid template: #{format_reason(reason)}"}

      {:error, {:eval, reason, []}} ->
        {:error, "Eval error: #{format_reason(reason)}"}

      {:error, {:eval, _reason, diags}} ->
        {:error, "Failed to execute template: #{flatten_diags(diags)}"}
    end
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  defp flatten_diags(errors) do
    Enum.map_join(errors, "; ", fn %{section, display} ->
      "<#{section}> #{display}"
    end)
  end

  defp not_empty(value, key) when is_binary(value) do
    value = String.trim(value)
    if not_empty_str(value), do: {:ok, value}, else: {:error, "Empty #{key}"}
  end

  defp not_empty(_, key), do: {:error, "Invalid #{key} as it is not a string"}
end
