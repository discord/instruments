defmodule Instruments do
  @moduledoc """
  Instruments allows you to easily create and emit metrics from your application.

  Getting started with instruments is simple, all you do is `use` this module, and
  you're off to the races.

  ```
  defmodule MyModule do
    use Instruments

    def compute_something() do
      Instruments.increment("computations")
    end
  end
  ```

  You can also create functions that are custom prefixed to avoide duplication in your code.
  See `Instruments.CustomFunctions` for more details.

  ## Metric Options

  All the functions in this module can be given an options keyword list, with one
  or both of the following keys:

  * `sample_rate`: A float, determining the percentage chance this metric will be emitted.
  * `tags`: A list of String tags that will be applied to this metric. Tags are useful for post-hoc grouping.
            For example, you could add instance type as a tag and visualize the difference between timing
            metrics of the same statistic across instance types to see which are the fastest.

  Here's an example of using options:

  ```elixir
  @type user_type :: :administrator | :employee | :normal
  @spec my_function(user_type, [User]) :: :ok
  def my_function(user_type, users) do
    Instruments.histogram("user_counts", Enum.count(users), sample_rate: 0.5, tags: [\"#\{user_type\}\"])
  end
  ```

  Now you can aggregate user counts by user type without emitting new stats

  ## Performance notes

  If a metric key has interpolation (such as `"my_metric.#\{Mix.env\}"`), the interpolation is removed and the metric name is converted to
  IOdata. This will prevent garbage being created in your process.

  """

  alias Instruments.{
    FastCounter,
    MacroHelpers,
    Probe,
    Probes
  }

  @metrics_module Application.get_env(:instruments, :reporter_module, Instruments.Statix)
  @statsd_port Application.get_env(:instruments, :statsd_port, 8125)

  defmacro __using__(_opts) do
    quote do
      require Instruments
    end
  end

  @doc false
  def statsd_port(), do: @statsd_port

  # metrics macros
  @doc false
  defdelegate connect(), to: @metrics_module

  @doc """
  Increments a counter

  Increments the counter with name `key` by `value`.
  """
  defmacro increment(key, value \\ 1, options \\ []),
    do: MacroHelpers.build_metric_macro(:increment, __CALLER__, FastCounter, key, value, options)

  @doc """
  Decrements a counter

  Decrements the counter with the key `key` by `value`.
  """
  defmacro decrement(key, value \\ 1, options \\ []),
    do: MacroHelpers.build_metric_macro(:decrement, __CALLER__, FastCounter, key, value, options)

  @doc """
  Sets a gauge value

  Sets the Gauge with key `key` to `value`, overwriting the previous value. Gauges are useful
  for system metrics that have a specific value at a specific time.
  """
  defmacro gauge(key, value, options \\ []),
    do: MacroHelpers.build_metric_macro(:gauge, __CALLER__, @metrics_module, key, value, options)

  @doc """
  Adds a value to a histogram

  Reports `value` to a histogram with key `key`. A Histogram is useful if you want to see
  aggregated percentages, and are often used when recording timings.
  """
  defmacro histogram(key, value, options \\ []),
    do:
      MacroHelpers.build_metric_macro(
        :histogram,
        __CALLER__,
        @metrics_module,
        key,
        value,
        options
      )

  @doc """
  Reports a timed value

  If you're manually timing something, you can use this function to report its value. Timings
  are usually added to a histogram and reported as percentages. If you're interested in timing
  a function, you should also see `Instruments.measure/3`.
  """
  defmacro timing(key, value, options \\ []),
    do: MacroHelpers.build_metric_macro(:timing, __CALLER__, @metrics_module, key, value, options)

  @doc """
  Adds `value` to a set

  Statsd supports the notion of [sets](https://github.com/etsy/statsd/blob/master/docs/metric_types.md#sets),
  which are unique values in a given flush. This adds `value`
  to a set with key `key`.

  """
  defmacro set(key, value, options \\ []),
    do: MacroHelpers.build_metric_macro(:set, __CALLER__, @metrics_module, key, value, options)

  @doc """
  Times the function `function` and returns its result

  This function allows you to time a function and send a metric in one call, and can often be
  easier to use than the `Instruments.timing/3` function.

  For example this:
      def timed_internals() do
        {run_time_micros, result} = :timer.tc(&other_fn/0)
        Instruments.timing("my.metric", run_time_micros)
        result
      end

  Can be converted to:
      def timed_internals() do
        Instruments.measure("my.metric", &other_fn/0)
      end

  """
  defmacro measure(key, options \\ [], function),
    do:
      MacroHelpers.build_metric_macro(
        :measure,
        __CALLER__,
        @metrics_module,
        key,
        options,
        function
      )

  @doc """
  Sends an event to DataDog

  This function is useful if you want to record one-off events like deploys or metrics values changing.
  """
  @spec send_event(iodata, iodata, Statix.options()) :: :ok
  defmacro send_event(title_ast, text, opts \\ []) do
    title_iodata = MacroHelpers.to_iolist(title_ast, __CALLER__)

    quote do
      title = unquote(title_iodata)

      header = [
        "_e{",
        Integer.to_charlist(IO.iodata_length(title)),
        ",",
        Integer.to_charlist(IO.iodata_length(unquote(text))),
        "}:",
        title,
        "|",
        unquote(text)
      ]

      message =
        case Keyword.get(unquote(opts), :tags) do
          nil ->
            header

          tag_list ->
            [header, "|#", Enum.intersperse(tag_list, ",")]
        end

      # Statix registers a port to the name of the metrics module.
      # and this code assumes that the metrics module is bound to
      # a port, and sends directly to it. If we move off of Statix,
      # this will have to be changed.
      unquote(@metrics_module)
      |> Process.whereis()
      |> :gen_udp.send('localhost', Instruments.statsd_port(), message)
    end
  end

  @doc false
  def flush_all_probes(wait_for_flush \\ true, flush_timeout_ms \\ 10_000) do
    Probe.Supervisor
    |> Process.whereis()
    |> Supervisor.which_children()
    |> Enum.each(fn {_, pid, _, _module} ->
      Probe.Runner.flush(pid)
    end)

    if wait_for_flush do
      Process.sleep(flush_timeout_ms)
    end
  end

  @doc """
  Registers the following probes:

    1. `erlang.memory`: Reports how much memory is being used by the `process`, `system`, `atom`, `binary` and `ets` carriers.
    1. `recon.alloc`: Reports how much memory is being actively used by the VM.
    1. `erlang.system.process_count`: A gauge reporting the number of processes in the VM.
    1. `erlang.system.port_count`: A gauge reporting the number of ports in the VM.
    1. `erlang.statistics.run_queue`: A gauge reporting the VM's run queue. This number should be 0 or very low. A high run queue indicates your system is overloaded.
    1. `erlang.scheduler_utilization`: A gauge that reports the actual utilization of every scheduler in the system. See `Instruments.Probes.Schedulers` for more information
  """
  @spec register_vm_metrics(Number.t()) :: :ok
  def register_vm_metrics(report_interval \\ 10000) do
    # VM memory.
    # processes = used by Erlang processes, their stacks and heaps.
    # system = used but not directly related to any Erlang process.
    # atom = allocated for atoms (included in system).
    # binary = allocated for binaries (included in system).
    # ets = allocated for ETS tables (included in system).
    Probe.define!("erlang.memory", :gauge,
      mfa: {:erlang, :memory, []},
      keys: ~w(processes system atom binary ets)a,
      report_interval: report_interval
    )

    # Memory actively used by the VM, allocated (should ~match OS allocation),
    # unused (i.e. allocated - used), and usage (used / allocated).
    alloc_keys = ~w(used allocated unused usage)a

    Probe.define!("recon.alloc", :gauge,
      function: fn ->
        for type <- alloc_keys, into: Keyword.new() do
          {type, :recon_alloc.memory(type)}
        end
      end,
      keys: alloc_keys,
      report_interval: report_interval
    )

    # process_count = current number of processes.
    # port_count = current number of ports.
    system_keys = ~w(process_count port_count)a

    Probe.define!("erlang.system", :gauge,
      function: fn ->
        for key <- system_keys do
          {key, :erlang.system_info(key)}
        end
      end,
      keys: system_keys,
      report_interval: report_interval
    )

    # The number of processes that are ready to run on all available run queues.
    Probe.define!("erlang.statistics.run_queue", :gauge,
      mfa: {:erlang, :statistics, [:run_queue]},
      report_interval: report_interval
    )

    Probe.define!("erlang.scheduler_utilization", :gauge,
      module: Probes.Schedulers,
      keys: ~w(weighted total)a,
      report_interval: report_interval
    )

    :ok
  end
end
