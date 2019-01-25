# Instruments: Simple, powerful and fast metrics for Statsd and DataDog

You're blind without metrics. Metrics should also be easy to add to you application
and have little performance impact. This module allows you to define metrics
with ease and see inside your application.

Instruments has the following types of metrics that closely mirror statsd.

  * **Counters**: Allow you to increment or decrement a value.
  * **Gauges**: Allow you to report a single value that changes over time
  * **Histograms**: Values are grouped into percentiles
  * **Timings**: Report a timed value in milliseconds
  * **Measurements**: Measure the execution time of a function
  * **Sets**: Add a value to a statsd set
  * **Events**: Report an event like a deploy using arbitrary keys and values

## Getting Started

Head over to the [pages directory](https://github.com/discordapp/instruments/tree/master/pages) and take a look through
the different guides to learn how to get started with Instruments

## Basic Usage

Reporting a metric is extremely simple; just `use` the Instruments module and call the
appropriate function:

```elixir
defmodule ModuleThatNeedsMetrics do
  use Instruments

  def other_function() do
    Process.sleep(150)
  end

  def metrics_function() do
    Instruments.increment("my.counter", 3)
    Instruments.measure("metrics_function.other_fn_call", &other_function/0)
  end
end
```

### Custom Namespaces
Often, all metrics inside a module have namespaced metrics. This is easy to accomplish
using `CustomFunctions`

```elixir
defmodule RpcHandler do
  use Instruments.CustomFunctions, prefix: "my_service.rpc"

  def handle(:get, "/foo/bar") do
    increment("foo.bar")
  end
end
```

The above example will increment the "my_service.rpc.foo.bar" metric by one.

## Probes
A probe is a metric that's periodically updated, like memory usage. It can be
tedious to define these on your own, so Instruments automates this process.
There are several different ways to define a probe:

The first, and easiest is to use the `:mfa` key, which takes a tuple of
`{Module, function, arguments}`

```elixir
Probe.define!("erlang.process_count", :gauge,
  mfa: {:erlang, :system_info, [:process_count]})
```

The above will report the process count every ten seconds.
You can also select keys from a value. For example, when reporting memory usage:

```elixir
Probe.define("erlang.memory", :gauge,
  mfa: {:erlang, :memory, []},
  keys: [:total, :processes])
```

In the above example, the `:erlang.memory()` function will be called, and it returns a
keyword list like:

```elixir
[total: 19371280, processes: 4638128, processes_used: 4633792, system: 14733152,
 atom: 264529, atom_used: 250724, binary: 181960, code: 5843599, ets: 383504]
```

From this, the probe extracts the `:total` and `:processes` keys, creates two metrics,
`erlang.memory.total` and `erlang.memory.processes` and reports them.

You can also define probes via a passed in zero argument function.

```elixir
Probe.define!("erlang.memory", :gauge,
  function: &:erlang.memory/0,
  keys: [:total, :processes])
```

The above function simplifies the earlier mfa example, above, calling `:erlang.memory()`
and extracting the `:total` and `:processes` keys.

Finally, if this isn't enough flexibility, you can implement the `Probe` behaviour and
pass in the module of your probe:

```elixir
defmodule MyProbe do
  @behaviour Instruments.Probe
  # implementation of the callbacks
end

Probe.define!("my.probe", :gauge, module: MyProbe)
```

Your probe module will now experience lifecycle callbacks and can keep its own state.
More information on the `Probe` behaviour is in the `Instruments.Probe` moduledoc.

Probes also have two other options:

  * `report_interval`: (milliseconds) How often the probe is reported to the
     underlying stats package.

  * `sample_interval`: (milliseconds) How often the probe's data is collected.
     If not set, this defaults to the `report_interval`.

## Performance

There are a couple optimizations that keep Instruments fast.

#### ETS backed counters
Probe counters actually increment or decrement a value in an ETS table, every
`fast_counter_report_interval` milliseconds, the aggregated values are flushed to
statsd. Because of this, counters are effectively free and with a conservative flush interval,
will put little pressure on your statsd server.

#### IOData metric names

Instruments uses macros to implement the metric names, and automatically converts interpolated
strings into IOLists. This means you can have many generated names without increasing the
amount of binary memory you're using. For example:

```elixir
def increment_rpc(rpc_name),
  do: Instruments.increment("my_module.rpc.#{rpc_name}")
```

will be rewritten to the call:

```elixir
def increment_rpc(rpc_name),
  do: Instruments.increment(["my_module.rpc.", Kernel.to_string(rpc_name)])
```

If you wish, you may pass any IOData as the name of a metric.

#### Sample Rates
For histograms, measure calls and timings, the default sample rate is pegged to 0.1.
This is so you don't accidentally overload your metrics collector. It can be
overridden by passing `sample_rate: float_value` to your metrics call in the
options.
