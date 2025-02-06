defmodule Instruments.Sysmon.Supervisor do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    emitter = Application.get_env(:instruments, :sysmon_emitter, Instruments.Sysmon.Emitter.Metrics)
    children = [
      {Instruments.Sysmon.Reporter, []},
      {emitter, []}
    ]

    Supervisor.init(children, strategy: :rest_for_one, name: __MODULE__)
  end
end
