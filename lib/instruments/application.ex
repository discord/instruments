defmodule Instruments.Application do
  @moduledoc false

  use Application
  alias Instruments.{
    FastCounter,
    Probe
  }

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    reporter = Application.get_env(:instruments, :reporter_module, Instruments.Statix)
    reporter.connect()

    children = [
      worker(FastCounter, []),
      worker(Probe.Definitions, []),
      worker(Probe.Supervisor, [])
    ]

    opts = [strategy: :one_for_one, name: Instruments.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
