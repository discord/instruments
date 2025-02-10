defmodule Instruments.Sysmon.Reporter do
  @moduledoc """
  Since only one process can subscribe to system monitor events, the Reporter
  acts as a relay for system monitor events, allowing multiple subscribers to
  receive system monitor events.

  On startup, the Reporter will subscribe to the system monitor events
  configured in `:sysmon_events` in the `:instruments` application environment.
  If no events are configured, the Reporter will not subscribe to any events.
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

  @doc """
  Subscribes the provided pid to configured system monitor events.
  """
  @spec subscribe(pid()) :: :ok
  def subscribe(pid \\ self()) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  @doc """
  Unsubscribes the provided pid from system monitor events.
  """
  @spec unsubscribe(pid()) :: :ok
  def unsubscribe(pid \\ self()) do
    GenServer.call(__MODULE__, {:unsubscribe, pid})
  end

  @doc """
  Sets the system monitor events to subscribe to. If no events are provided, the Reporter will not register itself as the system monitor process.
  """
  @spec set_events([sysmon_event()]) :: :ok
  def set_events(events) do
    GenServer.call(__MODULE__, {:set_events, events})
  end

  @doc """
  Returns the system monitor events the Reporter is subscribed to.
  """
  @spec get_events() :: [sysmon_event()]
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
    entries =  Enum.filter(state.subscribers, fn {_, p} -> p == pid end)

    state =
      case entries do
        [{ref, _pid}] ->
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

  defp enable_sysmon(nil) do
    enable_sysmon([])
  end

  defp enable_sysmon([]) do
    :ok
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
        Logger.warn("Overwriting system monitor process: #{inspect(pid)}")
    end

    :erlang.system_monitor(our_pid, events)
  end
end
