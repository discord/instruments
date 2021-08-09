defmodule Instruments.Probe.Supervisor do
  @moduledoc false
  use DynamicSupervisor

  def start_link(_ \\ []) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_probe(name, type, options, probe_module) do
    DynamicSupervisor.start_child(__MODULE__, {Instruments.Probe.Runner, {name, type, options, probe_module}})
  end
end
