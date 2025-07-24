defmodule Instruments.Application do
  @moduledoc false

  use Application

  alias Instruments.{
    FastCounter,
    FastGauge,
    Probe
  }

  def start(_type, _args) do
    reporter = Application.get_env(:instruments, :reporter_module, Instruments.Statix)
    reporter.connect()

    children = [
      FastCounter,
      FastGauge,
      Probe.Definitions,
      Probe.Supervisor,
    ]

    children = if Application.get_env(:instruments, :enable_sysmon, false) do
      [Instruments.Sysmon.Supervisor | children]
    else
      children
    end

    Supervisor.start_link(children, strategy: :one_for_one, name: Instruments.Supervisor)
  end
end
