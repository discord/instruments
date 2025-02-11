defmodule Instruments.Sysmon.Supervisor do
  @moduledoc """
  The system monitor is broken into three concepts: the Reporter, the Emitter,
  and the Receiver.

  The Reporter subscribes to `:erlang.system_monitor` and will forward system
  monitor events it receives to subscribers.

  The Emitter is responsible for receiving events from the Reporter and invoking
  the appropriate handler on the Receiver.

  Since only one process can subscribe to system monitor events, this is opt-in
  and must be enabled by setting `:enable_sysmon` to `true` in the
  `:instruments` application environment.
  """

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
