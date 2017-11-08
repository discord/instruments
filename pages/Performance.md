# Performance

There are a couple optimizations that keep Instruments fast.

### ETS backed counters
Probe counters actually increment or decrement a value in an ETS table, every
`fast_counter_report_interval` milliseconds, the aggregated values are flushed to
statsd. Furthermore, the ETS tables are sharded across schedulers and can be written to
without any concurrency. Because of this, counters are effectively free and with a 
conservative flush interval, will put little pressure on your statsd server.

### IOData metric names

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

### Sample Rates
For histograms, measure calls and timings, the default sample rate is pegged to 0.1.
This is so you don't accidentally overload your metrics collector. It can be
overridden by passing `sample_rate: float_value` to your metrics call in the
options.
