defmodule Test.Rivet.Mailer.Config.IndexTest do
  use Test.Support.Mailer.Case
  alias Rivet.Mailer.Config

  test "config test" do
    # clear cache of any other tests data
    Config.Cache.clear()

    {:ok, %Config{id: id, site: "default", group: "addr", key: "boop", value: "somefin"}} =
      Config.Cache.set("addr", "boop", "somefin")

    # change the value and also test list/string email tuples
    {:ok, %Config{id: ^id, value: ["a", "b"]}} = Config.Cache.set("addr", "boop", ["a", "b"])

    {:error, %{valid?: false, errors: [value: {"is invalid", _}]}} =
      Config.Cache.set("addr", "boop", 1)

    assert {:error, :not_found} = Config.Cache.conf("spleen", "boop")

    assert {:ok, %Config{}} = Config.Cache.set("spleen", "boop", "sploop")

    assert {:ok, "sploop"} = Config.Cache.conf("spleen", "boop")

    assert {:ok, %{spleen: %{boop: "sploop"}}} = Config.load_site("default")

    # raised
    assert_raise RuntimeError, fn ->
      Config.Cache.conf!("spleen", "boop", "nosite")
    end
  end
end
