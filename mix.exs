defmodule Instruments.Mixfile do
  use Mix.Project

  @version "1.1.0"
  @github_url "https://github.com/discordapp/instruments"

  def project do
    [
      app: :instruments,
      name: "Instruments",
      version: @version,
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      elixirc_paths: compile_paths(Mix.env),
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description()
    ]
  end

  def docs do
    [
      extras: [
        "pages/Overview.md",
        "pages/Configuration.md",
        "pages/Probes.md",
        "pages/Performance.md"
      ],

    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Instruments.Application, []}
    ]
  end

  def compile_paths(:test) do
    default_compile_path() ++ ["test/support"]
  end
  def compile_paths(_), do: default_compile_path()

  defp default_compile_path(), do: ["lib"]

  defp deps do
    [
      {:ex_doc, "~> 0.18.1", only: :dev, runtime: false},
      {:recon, "~> 2.3.1"},
      {:statix, "~> 1.0.1"},
    ]
  end

  defp description do
    "A small, fast, and unobtrusive metrics library"
  end

  defp package do
    [
      name: "instruments",
      files: ["lib", "pages", "README*", "LICENSE"],
      maintainers: ["Discord Core Infrastructure"],
      licenses: ["MIT"],
      source_url: @github_url,
      links: %{"GitHub" => @github_url}
    ]
  end
end
