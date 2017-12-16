# Configuration

### Statix

After the underlying `Statix` library is configured, `Instruments` requires little configuration.
To configure `Statix`, include the following in your `config/config.exs` file:

```elixir 
config :statix, 
  prefix: "#{Mix.env}",
  host: "localhost",
  port: 15339 
```
This should be pretty self-explanatory, other than you'll have a metric prefix of your 
Mix.env for all metrics, so if you defined a metric named `my_server.requests_per_second` it would be 
converted to `prod.my_server.requests_per_second`. 

More information can be found on the [Statix GitHub page](https://github.com/lexmag/statix#configuration).

### Instruments-Specific Config 

There are a couple of `Instruments` specific application variables: 

* `reporter_module`: The `Instruments.StatsReporter` that emits statistics for the application. Defaults
                     to `Instruments.Statix`.
* `fast_counter_report_interval`: How often counters should send data to the `reporter_module`. Defaults
                                  to 10 seconds.
* `probe_prefix`: A global prefix to apply to all probes.
* `statsd_port`: The port that the statsd server listens on. Should be the same as the port in the statix 
                 configuration above.

For example:

     config :instruments, 
       reporter_module: Instruments.Reporters.Logger,
       fast_counter_report_interval: 30_000,
       probe_prefix: "probes",
       statsd_port: 15339
