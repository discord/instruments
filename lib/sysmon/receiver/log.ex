defmodule Instruments.Sysmon.Receiver.Log do
  @moduledoc """
  This module emits system monitor events
  """

  @behaviour Instruments.Sysmon.Receiver

  require Logger

  @impl true
  def handle_busy_port(pid, port) do
    Logger.warning("Busy port: #{inspect(pid)} #{inspect(port)}")
  end

  @impl true
  def handle_busy_dist_port(pid, port) do
    Logger.warning("Busy dist port: #{inspect(pid)} #{inspect(port)}")
  end

  @impl true
  def handle_long_gc(pid, info) do
    Logger.warning("Long GC: #{inspect(pid)} #{inspect(info)}")
  end

  @impl true
  def handle_long_message_queue(pid, long) do
    if long do
      Logger.warning("Long message queue: #{inspect(pid)}")
    else
      Logger.info("Long message queue resolved: #{inspect(pid)}")
    end
  end

  @impl true
  def handle_long_schedule(pid, info) do
    Logger.warning("Long schedule: #{inspect(pid)} #{inspect(info)}")
  end

  @impl true
  def handle_large_heap(pid, info) do
    Logger.warning("Large heap: #{inspect(pid)} #{inspect(info)}")
  end
end
