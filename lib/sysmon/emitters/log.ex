defmodule Instruments.Sysmon.Emitters.Log do
  @moduledoc """
  This module emits system monitor events
  """
  use GenServer

  require Logger

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
  def handle_info({Reporter, event, data}, state) do
    Logger.warning("Received #{inspect(event)} with data #{inspect(data)}")
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
