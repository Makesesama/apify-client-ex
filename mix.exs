defmodule ApifyClient.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/Makesesama/apify-client-ex"

  def project do
    [
      app: :apify_client,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5.0"},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},

      # Dev/test dependencies
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:reqord, github: "Makesesama/reqord", branch: "async-writer", only: :test}
    ]
  end

  defp description do
    "Unofficial Elixir client library for the Apify API"
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Apify" => "https://apify.com",
        "API Documentation" => "https://docs.apify.com/api/v2"
      },
      maintainers: ["Makesesama"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        Core: [
          ApifyClient,
          ApifyClient.Config,
          ApifyClient.HTTPClient
        ],
        Resources: [
          ApifyClient.Actor,
          ApifyClient.Dataset,
          ApifyClient.KeyValueStore,
          ApifyClient.RequestQueue,
          ApifyClient.Run,
          ApifyClient.Build,
          ApifyClient.Task,
          ApifyClient.Schedule,
          ApifyClient.Webhook,
          ApifyClient.User
        ],
        Base: [
          ApifyClient.ResourceClient,
          ApifyClient.ResourceCollectionClient
        ],
        Errors: [
          ApifyClient.Error
        ]
      ]
    ]
  end
end
