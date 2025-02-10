defmodule Instruments.Sysmon.Emitter do
  @moduledoc """
  The Emitter is a simple module that subscribes to the Reporter and will invoke
  the corresponding handler on the Receiver.
  """

  use GenServer

  require Logger

  alias Instruments.Sysmon.Reporter

  defstruct [
    receiver_module: nil
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sets the receiver module to handle system monitor events. Receiver modules must implement the `Instruments.Sysmon.Receiver` behaviour.
  """
  @spec set_receiver(term()) :: :ok
  def set_receiver(receiver_module) do
    GenServer.call(__MODULE__, {:set_receiver, receiver_module})
  end

  @impl true
  def init(_) do
    Reporter.subscribe()
    {:ok, %__MODULE__{
      receiver_module: Application.get_env(:instruments, :sysmon_receiver, Instruments.Sysmon.Receiver.Metrics)
    }}
  end


  @impl true
  def handle_call({:set_receiver, receiver_module}, _from, %__MODULE__{} = state) do
    {:reply, :ok, %__MODULE__{state | receiver_module: receiver_module}}
  end

  @impl true
  def handle_info({Reporter, event, data}, state) do
    handle_event(state, event, data)
    {:noreply, state}
  end

  def handle_info(unknown, state) do
    Logger.error("Emitter received unknown message: #{inspect(unknown)}")
    {:noreply, state}
  end

  defp handle_event(%__MODULE__{} = state, :busy_dist_port, %{pid: pid, port: port}) do
    state.receiver_module.handle_busy_dist_port(pid, port)
  end

  defp handle_event(%__MODULE__{} = state, :busy_port, %{pid: pid, port: port}) do
    state.receiver_module.handle_busy_port(pid, port)
  end

  defp handle_event(%__MODULE__{} = state, :long_gc, %{pid: pid, info: info}) do
    state.receiver_module.handle_long_gc(pid, info)
  end

  defp handle_event(%__MODULE__{} = state, :long_message_queue, %{pid: pid, info: long}) do
    state.receiver_module.handle_long_message_queue(pid, long)
  end

  defp handle_event(%__MODULE__{} = state, :long_schedule, %{pid: pid, info: info}) do
    state.receiver_module.handle_long_schedule(pid, info)
  end

  defp handle_event(%__MODULE__{} = state, :large_heap, %{pid: pid, info: info}) do
    state.receiver_module.handle_large_heap(pid, info)
  end

  defp handle_event(%__MODULE__{}, event, data) do
    Logger.warn("Emitter received unknown event #{inspect(event)} with data #{inspect(data)}")
  end
end
