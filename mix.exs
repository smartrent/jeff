defmodule Jeff.MixProject do
  use Mix.Project

  @version "0.4.0"

  def project do
    [
      app: :jeff,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      dialyzer: dialyzer(),
      elixirc_paths: elixirc_paths(Mix.env()),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_uart, "~> 1.4"},
      {:cerlc, "~> 0.2.0"},
      {:connection, "~> 1.1.0"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "An Elixir implementation of the Open Supervised Device Protocol (OSDP)."
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs],
      list_unused_filters: true
    ]
  end

  defp docs() do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      logo: "assets/logo-simple.png",
      source_ref: "v#{@version}",
      source_url: "https://github.com/smartrent/jeff"
    ]
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/smartrent/jeff"}
    ]
  end
end
