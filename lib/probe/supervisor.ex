defmodule Instruments.Probe.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      worker(Instruments.Probe.Runner, [])
    ]

    supervise(children, strategy: :simple_one_for_one, name: __MODULE__)
  end

  def start_probe(name, type, options, probe_module) do
   Supervisor.start_child(__MODULE__, [name, type, options, probe_module])
  end
end
