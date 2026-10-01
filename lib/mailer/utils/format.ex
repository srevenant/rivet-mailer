defmodule Rivet.Mailer.Utils.Format do
  require Logger
  alias Core.Db.Ident
  alias Ident.User
  use Rivet.Mailer
  import Core.Guards

  @default_human %{
    prefix: "",
    suffix: "",
    noname: ""
  }

  @doc """
  iex> id = Ecto.UUID.generate()
  iex> opts = %{prefix: "blue", suffix: "bork"}
  iex> "blue Narf bork" = human_name(%User{id: id, name: "", handle: %Core.Db.Ident.Handle{id: id, handle: "Narf"}}, opts)
  iex> "noname" = human_name(%User{id: id, name: "", handle: %Core.Db.Ident.Handle{id: id, handle: ""}}, %{noname: "noname"})
  """
  def human_name(%User{} = u, opts \\ []) do
    opts = Map.merge(@default_human, Map.new(opts))

    if not_empty_str(u.name) do
      "#{opts.prefix} #{u.name} #{opts.suffix}"
    else
      case User.preload(u, :handle) do
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
