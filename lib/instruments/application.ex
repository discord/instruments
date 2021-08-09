defmodule Instruments.Application do
  @moduledoc false

  use Application

  alias Instruments.{
    FastCounter,
    Probe
  }

  def start(_type, _args) do
    reporter = Application.get_env(:instruments, :reporter_module, Instruments.Statix)
    reporter.connect()

    children = [
      FastCounter,
      Probe.Definitions,
      Probe.Supervisor,
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Instruments.Supervisor)
  end
end
