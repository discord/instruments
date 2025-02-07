defmodule Instruments.Sysmon.Supervisor do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      Instruments.Sysmon.Reporter,
      Instruments.Sysmon.Emitter,
    ]

    Supervisor.init(children, strategy: :rest_for_one, name: __MODULE__)
  end
end
