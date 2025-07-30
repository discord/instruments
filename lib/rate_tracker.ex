defmodule Instruments.RateTracker do
  @moduledoc """
  RateTracker will track how often you are reporting metrics that are not backed 
  by a "fast" implementation.

  RateTracker is designed to catch cases where you have inadvertently reported 
  a metric "too" frequently, as some metrics require hitting statsd directly for 
  every reported value. Doing so in hot loops can result in your 
  application slowing significantly.
  """

  @table_prefix :instruments_rate_tracker
  @max_tables 128
  @report_interval_ms Application.get_env(
                        :instruments,
                        :rate_tracker_report_interval,
                        10_000
                      )
  @report_jitter_range_ms Application.get_env(
                            :instruments,
                            :rate_tracker_report_jitter_range,
                            -500..500
                          )

  @compile {:inline, get_table_key: 2}

  use GenServer

  @type t :: %__MODULE__{
          last_update_time: integer(),
          callbacks: [callback()],
          table_count: non_neg_integer()
        }

  @type callback :: ({String.t(), Statix.options()}, non_neg_integer() -> term())

  @enforce_keys [:last_update_time, :table_count]
  defstruct [
    :last_update_time,
    :table_count,
    callbacks: []
  ]

  def start_link(_ \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    table_count = :erlang.system_info(:schedulers)

    for scheduler_id <- 1..table_count do
      :ets.new(table_name(scheduler_id), [:named_table, :public, :set])
    end

    schedule_report()

    {:ok,
     %__MODULE__{
       last_update_time: time(),
       table_count: table_count,
       callbacks: []
     }}
  end

  ## Public
  @doc false
  @spec track(iodata) :: :ok
  @spec track(iodata, Statix.options()) :: :ok
  def track(name, options \\ []) do
    table_key = get_table_key(name, options)
    :ets.update_counter(current_table(), table_key, 1, {table_key, 0})

    :ok
  end

  @doc """
  Add a callback to be notified that you are reporting a metric "too" frequently.

  In order to receive notifications, you must set `:instruments` -> 
  `:rate_tracker_callback_threshold` to the per-second rate that you want to be 
  notified at. This value will be different for every system, and will require
  experimentation to determine. You can use `dump_rates()` in a remote console
  to see what values are currently tracked for your metrics.

  This callback should be short-lived.
  """
  @spec subscribe(callback()) :: :ok
  def subscribe(callback) do
    GenServer.cast(__MODULE__, {:subscribe, callback})
  end

  @doc """
  Dump the currently tracked rates
  """
  @spec dump_rates() :: [{{String.t(), Keyword.t()}, non_neg_integer()}]
  def dump_rates() do
    table_count = :erlang.system_info(:schedulers)

    1..table_count
    |> Enum.flat_map(fn scheduler_id ->
      scheduler_id
      |> table_name()
      |> :ets.tab2list()
    end)
    |> aggregate_stats()
    |> Enum.filter(fn
      {_key, 0} -> false
      {_key, _rate} -> true
    end)
    |> Enum.to_list()
  end

  ## GenServer callbacks

  def handle_cast({:subscribe, callback}, %__MODULE__{} = state) do
    state = %__MODULE__{state | callbacks: [callback | state.callbacks]}

    {:noreply, state}
  end

  def handle_info(:report, %__MODULE__{} = state) do
    report_time = time()
    time_since_report = report_time - state.last_update_time
    threshold = Application.get_env(:instruments, :rate_tracker_callback_threshold, nil)

    # Extraordinarily unlikely to be zero, but if it is for some reason, we'll just skip this
    # and let the next report get it
    if threshold != nil and time_since_report > 0 do
      do_report(state, time_since_report, threshold)
    end

    schedule_report()
    {:noreply, %__MODULE__{state | last_update_time: report_time}}
  end

  ## Private

  defp get_table_key(name, []) do
    {name, []}
  end

  defp get_table_key(name, options) do
    case Keyword.get(options, :tags) do
      [] ->
        {name, options}

      [_] ->
        {name, options}

      tags when is_list(tags) ->
        {name, Keyword.replace!(options, :tags, Enum.sort(tags))}

      _ ->
        {name, options}
    end
  end

  defp sample_rate_for_key({_name, opts}) do
    Keyword.get(opts, :sample_rate, 1)
  end

  defp schedule_report() do
    wait_time = @report_interval_ms + Enum.random(@report_jitter_range_ms)
    Process.send_after(self(), :report, wait_time)
  end

  defp time() do
    # Dividing so we can get the fractional part
    System.monotonic_time(:microsecond) / 1_000_000
  end

  defp current_table() do
    table_name(:erlang.system_info(:scheduler_id))
  end

  defp aggregate_stats(table_data) do
    Enum.reduce(table_data, %{}, fn {key, val}, acc ->
      Map.update(acc, key, val, &(&1 + val))
    end)
  end

  defp do_report(%__MODULE__{} = state, time_since_report, threshold) do
    dump_and_flush_data = fn scheduler_id ->
      table_name = table_name(scheduler_id)
      table_data = :ets.tab2list(table_name)

      Enum.each(table_data, fn {key, val} ->
        :ets.update_counter(table_name, key, -val)
      end)

      table_data
    end

    1..state.table_count
    |> Enum.flat_map(dump_and_flush_data)
    |> aggregate_stats()
    |> Enum.each(fn {key, num_tracked} ->
      # Sampling correction  is technically approximate (we don't know if Statix or another underlying lib will report this differently)
      tracked_per_second = num_tracked / time_since_report * sample_rate_for_key(key)

      if tracked_per_second > threshold do
        Enum.each(state.callbacks, fn callback -> callback.(key, tracked_per_second) end)
      end
    end)
  end

  for scheduler_id <- 1..@max_tables do
    defp table_name(unquote(scheduler_id)) do
      unquote(:"#{@table_prefix}_#{scheduler_id}")
    end
  end
end
