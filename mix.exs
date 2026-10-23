defmodule Rivet.Mailer.MixProject do
  use Mix.Project

  @source_url "https://github.com/srevenant/rivet-ident"
  @xref_ignore_modules [
    :repo
    #   :user_model,
    #   :user_code_model,
    #   :email_model,
    #   :email_issue_model,
    #   :handle_model
  ]
  def project do
    [
      app: :rivet_mailer,
      version: "2.0.0",
      elixir: "~> 1.18",
      description: "Templated mail dispatcher system",
      source_url: @source_url,
      docs: docs(),
      package: package(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        dialyzer: :test
      ],
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      # this stops the warnings about a schema not existing, but only
      # for compiler module check warnings. It will not stop the Ecto
      # warnings.
      xref: [exclude: Enum.map(@xref_ignore_modules, &Application.get_env(:rivet, &1))],
      aliases: aliases(),
      compilers: [:es6_maps | Mix.compilers()]
    ]
  end

  def application do
    [
      env: [rivet: [app: :rivet_mailer, base: Rivet.Mailer, models_dir: "mailer"]],
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test),
    do: ["lib", "test/support", "test/fixtures", "deps/rivet_ident/test/fixtures"]

  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "rivet migrate", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      # keystrokes of life
      c: ["compile"]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:es6_maps, "~> 1.0.2"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_machina, "~> 2.8", only: :test},
      {:excoveralls, "~> 0.14", only: :test},
      {:faker, "~> 0.18", only: [:dev, :test]},
      {:hackney, ">= 1.0.0", only: [:dev, :test]},
      {:markdownify_ex, "~> 1.2"},
      {:mix_test_watch, "~> 1.4", only: [:dev, :test], runtime: false},
      {:rivet_engram, "~> 2.0.0"},
      # {:rivet_ident, "~> 4.0.0"},
      {:rivet_ident, git: "https://github.com/srevenant/rivet-ident/", branch: "mailer-updates"},
      {:rivet_utils,
       git: "https://github.com/srevenant/rivet-utils/", branch: "v3", override: true},
      {:swoosh, "~> 1.19"}
      # {:typed_ecto_schema, "~> 0.3.0 or ~> 0.4.1"}

      # {:transmogrify, "~> 2.0.2"},
      # {:yaml_elixir, "~> 2.8"}
    ]
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs priv/rivet test/fixtures README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs(), do: [main: "Rivet.Mailer", extras: ["README.md"]]
end
