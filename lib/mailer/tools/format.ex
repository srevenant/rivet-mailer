defmodule Rivet.Mailer.Tools.Format do
  use Rivet.Mailer

  @default_human %{
    prefix: "",
    suffix: "",
    noname: ""
  }

  @doc """
  iex> id = Ecto.UUID.generate()
  iex> opts = %{prefix: "blue", suffix: "bork"}
  iex> "blue Narf bork" = human_name(%@user_model{id: id, name: "", handle: %Rivet.Ident.@handle_model{id: id, handle: "Narf"}}, opts)
  iex> "noname" = human_name(%@user_model{id: id, name: "", handle: %Rivet.Ident.@handle_model{id: id, handle: ""}}, %{noname: "noname"})
  """
  def human_name(%@user_model{} = u, opts \\ []) do
    opts = Map.merge(@default_human, Map.new(opts))

    if not_empty_str(u.name) do
      "#{opts.prefix} #{u.name} #{opts.suffix}"
    else
      case @user_model.preload(u, :handle) do
        {:ok, %{handle: %{handle: handle}}} when not_empty_str(handle) ->
          "#{opts.prefix} #{handle} #{opts.suffix}"

        _ ->
          opts.noname
      end
    end
    |> String.trim()
  end

  @doc ~S"""
  iex> html2text("<b>an html doc</b><p><h1>Header</h1>")
  "**an html doc**\n\n# Header"
  """
  @spec html2text(html :: String.t()) :: text :: String.t()
  def html2text(html), do: Html2Markdown.convert(html)
end
