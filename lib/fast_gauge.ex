defmodule Instruments.FastGauge do
  @moduledoc false
  # Instruments.FastGauge sets up one ETS table per scheduler, and calls to
  # `gauge/3` insert into the table for the current scheduler.
  # The key for the table entry is built out of the gauge name and options.
  # The value for the table entry includes the gauge value as well as the timestamp
  # it was recorded at.
  #
  # The Instruments.FastGauge process periodically reports the most recent value
  # for every table key, deleting entries that have been reported or ignored.
  @table_prefix :instruments_gauges
  @max_tables 128
  @report_interval_ms Application.compile_env(
                        :instruments,
                        :fast_gauge_report_interval,
                        10_000
                      )
  @report_jitter_range_ms Application.compile_env(
                            :instruments,
                            :fast_gauge_report_jitter_range,
                            -500..500
                          )
  @compile {:inline, get_table_key: 2, latest_table_entry_value: 2}

  @type table_entry_value :: {gauge_value :: number(), recorded_timestamp :: pos_integer()}

  use GenServer

  def start_link(_ \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    table_count = :erlang.system_info(:schedulers)

    for scheduler_id <- 1..table_count do
      :ets.new(table_name(scheduler_id), [:named_table, :public, :set])
    end

    reporter_module = Application.get_env(:instruments, :reporter_module, Instruments.Statix)

    schedule_report()
    {:ok, {reporter_module, table_count}}
  end

  ## Public

  @spec gauge(iodata, integer) :: :ok
  @spec gauge(iodata, integer, Statix.options()) :: :ok
  def gauge(name, value, options \\ []) do
    table_key = get_table_key(name, options)
    timestamp = System.monotonic_time()
    :ets.insert(current_table(), [{table_key, {value, timestamp}}])
  end

  ## GenServer callbacks
  def handle_info(:report, {reporter_module, table_count} = state) do
    1..table_count
    |> Enum.map(fn scheduler_id -> table_name(scheduler_id) end)
    |> Enum.reduce(%{}, fn table_name, acc ->
      table_results = :ets.tab2list(table_name) |> Map.new()

      Enum.each(table_results, & :ets.delete_object(table_name, &1))

      Map.merge(acc, table_results, fn key, value_old, value_new ->
        latest_table_entry_value(value_old, value_new)
      end)
    end)
    |> Enum.each(
      fn {table_key, {value, _timestamp}} ->
        report_stat({table_key, value}, reporter_module)
      end
    )

    schedule_report()
    {:noreply, state}
  end

  ## Private
  defp current_table() do
    table_name(:erlang.system_info(:scheduler_id))
  end

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

  @spec latest_table_entry_value(table_entry_value(), table_entry_value()) :: table_entry_value()
  defp latest_table_entry_value({value_1, recorded_timestamp_1}, {_value_2, recorded_timestamp_2}) when recorded_timestamp_1 > recorded_timestamp_2 do
    {value_1, recorded_timestamp_1}
  end

  defp latest_table_entry_value({_value_1, recorded_timestamp_1}, {value_2, recorded_timestamp_2}) do
    {value_2, recorded_timestamp_2}
  end

  defp report_stat({{metric_name, opts}, value}, reporter_module) do
    reporter_module.gauge(metric_name, value, opts)
  end

  defp schedule_report() do
    wait_time = @report_interval_ms + Enum.random(@report_jitter_range_ms)
    Process.send_after(self(), :report, wait_time)
  end

  for scheduler_id <- 1..@max_tables do
    defp table_name(unquote(scheduler_id)) do
      unquote(:"#{@table_prefix}_#{scheduler_id}")
    end
  end
end
