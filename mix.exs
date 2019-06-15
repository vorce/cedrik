defmodule Cedrik.Mixfile do
  use Mix.Project

  def project do
    [
      app: :cedrik,
      version: "0.0.1",
      elixir: "~> 1.5",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [mod: {Cedrik, []}, applications: [:logger]]
  end

  defp deps do
    [
      {:chronos, "~> 1.7"},
      {:exredis, "~> 0.2"},
      {:poison, "~> 2.2"},
      {:credo, "~> 0.8", only: [:dev, :test]},
      {:inch_ex, "~> 0.5", only: [:dev, :test]}
    ]
  end
end
