defmodule Instruments.Sysmon.Reporter do
  @moduledoc """
  This module receives system monitor events and forwards them to other processes
  """
  use GenServer

  require Logger

  @type sysmon_event ::
          {:long_gc, pos_integer()}
          | {:long_schedule, pos_integer()}
          | {:large_heap, pos_integer()}
          | :busy_port
          | :busy_dist_port

  @type t :: %__MODULE__{
          subscribers: %{reference() => pid()},
          events: [sysmon_event()]
        }

  defstruct subscribers: Map.new(), events: []

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def subscribe(pid \\ self()) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  def unsubscribe(pid) do
    GenServer.call(__MODULE__, {:unsubscribe, pid})
  end

  def set_events(events) do
    GenServer.call(__MODULE__, {:set_events, events})
  end

  def get_events() do
    GenServer.call(__MODULE__, :get_events)
  end

  @impl true
  def init(_) do
    sysmon_events = Application.get_env(:instruments, :sysmon_events, [])
    enable_sysmon(sysmon_events)

    {:ok,
     %__MODULE__{
       events: sysmon_events
     }}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, %__MODULE__{} = state) do
    existing = Map.values(state.subscribers)

    state =
      if Enum.member?(existing, pid) do
        state
      else
        ref = Process.monitor(pid)

        %__MODULE__{
          state
          | subscribers: Map.put(state.subscribers, ref, pid)
        }
      end

    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, pid}, _from, %__MODULE__{} = state) do
    ref = Map.filter(state.subscribers, fn {_, p} -> p == pid end) |> Map.keys()

    state =
      case ref do
        [ref] ->
          Process.demonitor(ref)

          %__MODULE__{
            state
            | subscribers: Map.delete(state.subscribers, ref)
          }

        _ ->
          state
      end

    {:reply, :ok, state}
  end

  def handle_call({:set_events, events}, _from, %__MODULE__{} = state) do
    enable_sysmon(events)
    {:reply, :ok, %__MODULE__{state | events: events}}
  end

  def handle_call(:get_events, _from, %__MODULE__{} = state) do
    {:reply, state.events, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %__MODULE__{} = state) do
    state = %__MODULE__{
      state
      | subscribers: Map.delete(state.subscribers, ref)
    }

    {:noreply, state}
  end

  def handle_info(msg, %__MODULE__{} = state) do
    to_forward =
      case msg do
        {:monitor, pid, event, port} when event == :busy_dist_port or event == :busy_port ->
          {__MODULE__, event,
           %{
             pid: pid,
             port: port
           }}

        {:monitor, pid, event, info} ->
          {__MODULE__, event,
           %{
             pid: pid,
             info: info
           }}

        unknown ->
          {__MODULE__, :unknown, unknown}
      end

    Enum.each(state.subscribers, fn {_, pid} -> send(pid, to_forward) end)
    {:noreply, state}
  end

  defp enable_sysmon(events) do
    # Log if we're going to overwrite an existing system monitor
    our_pid = self()

    case :erlang.system_monitor() do
      :undefined ->
        # No system monitor is configured
        :ok

      {^our_pid, _} ->
        # We are already receiving system monitor events
        :ok

      {pid, _} ->
        # Another process is already receiving system monitor events, log a warning
        Logger.warning("Overwriting system monitor process: #{inspect(pid)}")
    end

    :erlang.system_monitor(our_pid, events)
  end
end
