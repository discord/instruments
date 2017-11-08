defmodule Instruments.Mixfile do
  use Mix.Project

  def project do
    [
      app: :instruments,
      version: "1.0.0",
      elixir: "~> 1.2",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      elixirc_paths: compile_paths(Mix.env),
      deps: deps(),
      docs: docs()
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
      extra_applications: [
        :logger
        # :os_mon,
      ],
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
end
