defmodule Instruments.Sysmon.Emitters.Metrics do
  @moduledoc """
  This module emits system monitor events
  """
  use GenServer

  require Instruments

  alias Instruments.Sysmon.Reporter

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_) do
    Reporter.subscribe()
    {:ok, %{}}
  end

  @impl true
  def handle_info({Reporter, :busy_dist_port, _}, state) do
    Instruments.increment("erlang.sysmon.busy_dist_port")
    {:noreply, state}
  end

  def handle_info({Reporter, :busy_port, _}, state) do
    Instruments.increment("erlang.sysmon.busy_port")
    {:noreply, state}
  end

  def handle_info({Reporter, :long_gc, _}, state) do
    Instruments.increment("erlang.sysmon.long_gc")
    {:noreply, state}
  end

  def handle_info({Reporter, :long_schedule, _}, state) do
    Instruments.increment("erlang.sysmon.long_schedule")
    {:noreply, state}
  end

  def handle_info({Reporter, :large_heap, _}, state) do
    Instruments.increment("erlang.sysmon.large_heap")
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
