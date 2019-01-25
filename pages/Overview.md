# Overview

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

## Custom Namespaces
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

The above example will increment the `my_service.rpc.foo.bar` metric by one.


