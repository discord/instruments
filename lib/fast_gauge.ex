defmodule Instruments.FastGauge do
  @table_name :instruments_gauges
  @report_interval_ms Application.get_env(
                        :instruments,
                        :fast_gauge_report_interval,
                        10_000
                      )
  @report_jitter_range_ms Application.get_env(
                            :instruments,
                            :fast_gauge_report_jitter_range,
                            -500..500
                          )
  @compile {:inline, get_table_key: 2}

  use GenServer

  def start_link(_ \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    :ets.new(@table_name, [:named_table, :public, :set])

    reporter_module = Application.get_env(:instruments, :reporter_module, Instruments.Statix)

    schedule_report()
    {:ok, reporter_module}
  end

  ## Public

  @spec gauge(iodata, integer) :: :ok
  @spec gauge(iodata, integer, Statix.options()) :: :ok
  def gauge(name, value, options \\ []) do
    table_key = get_table_key(name, options)
    :ets.insert(@table_name, [{table_key, value}])
  end

  ## GenServer callbacks
  def handle_info(:report, reporter_module = state) do
    @table_name
    |> :ets.tab2list()
    |> Enum.each(
      fn {table_key, value} ->
        report_stat({table_key, value}, reporter_module)

        # Delete the object only if the current value is the one we just reported
        # If we reported A and the value went from A -> B -> A, and we never report B,
        # oh well, that's just how a gauge works.
        :ets.delete_object(@table_name, {table_key, value})
      end
    )

    schedule_report()
    {:noreply, state}
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

  defp report_stat({{metric_name, opts}, value}, reporter_module) do
    reporter_module.gauge(metric_name, value, opts)
  end

  defp schedule_report() do
    wait_time = @report_interval_ms + Enum.random(@report_jitter_range_ms)
    Process.send_after(self(), :report, wait_time)
  end
end
