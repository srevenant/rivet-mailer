defmodule Rivet.Mailer.Tools.Format do
  use Rivet.Mailer

  @default_human %{
    prefix: "",
    suffix: "",
    noname: ""
  }

  def human_name(%{__struct__: @user_model} = u, opts \\ []) do
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

  @doc """
  This is a centralized call here so its easier for us to swap backends.

  Notes:

  * :html2markdown — lightweight, but has issues with slight variants to html like <p> unclosed, and runs as regex/replaces.
  * :html_to_markdown — a rust based NIF, but that means you need to have a rust compiler. So not portable.
  * :markdownify_ex — native erlang/elixir. maybe not as efficient but it works.

  Todo:

  * make it configurable, including added-opts?

  """
  @spec html2text(html :: String.t()) :: text :: String.t()
  def html2text(html), do: Markdownify.markdownify(html)
end
