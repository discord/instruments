defmodule Instruments.FastCounter do
  @moduledoc false

  # A Faster than normal counter.

  # Builds one ETS table per scheduler in the system and sends increment / decrement writes to the local
  # scheduler. Statistics are reported per scheduler once every `fast_counter_report_interval` milliseconds.

  @table_prefix :instruments_counters
  @max_tables 128
  @fast_counter_report_interval Application.get_env(:instruments, :fast_counter_report_interval, 10_000)

  use GenServer

  def start_link() do
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

  @spec increment(iodata) :: :ok
  @spec increment(iodata, integer) :: :ok
  @spec increment(iodata, integer, Statix.options) :: :ok
  def increment(name, amount \\ 1, options \\ []) do
    table_key =
      case Keyword.get(options, :tags) do
        tags when is_list(tags) ->
          {name, Keyword.merge(options, [tags: Enum.sort(tags)])}

        _ ->
          {name, options}
      end

    :ets.update_counter(current_table(), table_key, amount, {table_key, 0})
    :ok
  end

  @spec decrement(iodata) :: :ok
  @spec decrement(iodata, integer) :: :ok
  @spec decrement(iodata, integer, Statix.options) :: :ok
  def decrement(name, amount \\ 1, options \\ []),
    do: increment(name, -amount, options)

  ## GenServer callbacks
  def handle_info(:report, {reporter_module, table_count}=state) do

    # dump the scheduler's data and decrement its
    # counters by the amount we dumped.
    dump_and_flush_data = fn(scheduler_id) ->
      table_name = table_name(scheduler_id)
      table_data = :ets.tab2list(table_name)

      Enum.each(table_data, fn {key, val} ->
        :ets.update_counter(table_name, key, -val)
      end)
      table_data
    end

    # aggregates each scheduler's table into one metric
    aggregate_stats = fn({key, val}, acc) ->
      Map.update(acc, key, val, &(&1 + val))
    end

    1..table_count
      |> Enum.flat_map(dump_and_flush_data)
      |> Enum.reduce(%{}, aggregate_stats)
      |> Enum.each(&report_stat(&1, reporter_module))

    schedule_report()
    {:noreply, state}
  end

  ## Private

  defp report_stat({_key, 0}, _),
    do: :ok
  defp report_stat({{metric_name, opts}, value}, reporter_module) when value < 0 do
    # this -value looks like a bug, but isn't. Since we're aggregating
    # counters, the value could be negative, but the decrement
    # operation takes positive values.
    reporter_module.decrement(metric_name, -value, opts)
  end
  defp report_stat({{metric_name, opts}, value}, reporter_module) when value > 0 do
    reporter_module.increment(metric_name, value, opts)
  end

  defp schedule_report() do
    Process.send_after(self(), :report, @fast_counter_report_interval)
  end

  defp current_table() do
    table_name(:erlang.system_info(:scheduler_id))
  end

  for scheduler_id <- (1..@max_tables) do
    defp table_name(unquote(scheduler_id)) do
      unquote(:"#{@table_prefix}_#{scheduler_id}")
    end
  end
end
