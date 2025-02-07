defmodule Instruments.Sysmon.Receiver.Metrics do
  @moduledoc """
  This module emits system monitor events
  """
  require Instruments

  @behaviour Instruments.Sysmon.Receiver

  @impl true
  def handle_busy_dist_port(_, _) do
    Instruments.increment("erlang.sysmon.busy_dist_port")
  end

  @impl true
  def handle_busy_port(_, _) do
    Instruments.increment("erlang.sysmon.busy_port")
  end

  @impl true
  def handle_long_gc(_, _) do
    Instruments.increment("erlang.sysmon.long_gc")
  end

  @impl true
  def handle_long_message_queue(_, long) do
    Instruments.increment("erlang.sysmon.long_message_queue", tags: ["long:#{long}"])
  end

  @impl true
  def handle_long_schedule(_, _) do
    Instruments.increment("erlang.sysmon.long_schedule")
  end

  @impl true
  def handle_large_heap(_, _) do
    Instruments.increment("erlang.sysmon.large_heap")
  end
end
