defmodule Rivet.Mailer.Config.Cache do
  use Rivet.Utils.LazyCache
  alias Rivet.Mailer.Config

  @default_site "default"
  def set(group, key, value, site \\ @default_site),
    do:
      Config.replace(%{site: site, group: group, key: key, value: value},
        site: site,
        group: group,
        key: key
      )

  def load_site(site) do
    get_through(site, fn _ ->
      with {:ok, list} <- Config.all(site: site) do
        {:ok,
         Enum.reduce(list, %{}, fn %{group: group, key: key, value: value}, map ->
           group = String.to_atom(group)
           key = String.to_atom(key)
           put_in(map, [Access.key(group, %{}), key], value)
         end)}
      end
    end)
  end

  def conf(grp, key, site \\ @default_site) do
    get_through({site, grp, key}, fn _ ->
      with {:ok, %{value: value}} <- Config.one(site: site, group: grp, key: key),
           do: {:ok, value}
    end)
  end

  def conf!(grp, key, site \\ @default_site) do
    case conf(grp, key, site) do
      {:ok, value} -> value
      {:error, :not_found} -> raise "email config not found: #{site}.#{grp}.#{key}"
    end
  end

  @doc """
  iex> "Libreon" = getsite(:name)
  """
  def getsite(key), do: conf!("site", to_string(key))

  @doc """
  iex> ["Libreon Support", "libreon-support@libreon.net"] = getaddr(:support)
  """
  def getaddr(key), do: conf!("addrs", to_string(key))
end
