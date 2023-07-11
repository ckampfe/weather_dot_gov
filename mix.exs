defmodule WeatherDotGov.MixProject do
  use Mix.Project

  def project do
    [
      app: :weather_dot_gov,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:sweet_xml, "~> 0.7"},
      {:recase, "~> 0.7"},
      {:req, "~> 0.3"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  def description() do
    "An API client for weather.gov"
  end

  def package() do
    [
      licenses: ["BSD-3-Clause"],
      links: %{"GitHub" => "https://github.com/ckampfe/weather_dot_gov"}
    ]
  end
end
