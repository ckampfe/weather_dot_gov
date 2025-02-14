defmodule WeatherDotGov.MixProject do
  use Mix.Project

  def project do
    [
      app: :weather_dot_gov,
      version: "0.4.0",
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
      {:recase, "~> 0.8"},
      {:req, "~> 0.5", optional: true},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false}
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
