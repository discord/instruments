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
* `fast_counter_report_interval`: How often counters should send data to the `reporter_module`, in milliseconds. 
                                  Defaults to 10 seconds.
* `fast_counter_report_jitter_range`: How much random jitter should be applied to the reporting interval, in milliseconds.
                                      Defaults to half a second before and after the reporting interval.
* `probe_prefix`: A global prefix to apply to all probes.
* `statsd_host`: The hostname of the statsd server. Defaults to `"localhost"`. Should be the same as the host
                 in the statix configuration above.
* `statsd_port`: The port that the statsd server listens on. Should be the same as the port in the statix
                 configuration above.
* `enable_sysmon`: Enables and registers `Instruments.Sysmon.Reporter` with `:erlang.system_monitor/1` to receive system 
                   monitor events.
* `sysmon_receiver`: The `Instruments.Sysmon.Receiver` that handles sysmon events. Defaults to `Instruments.Sysmon.Receiver.Metrics`
* `sysmon_events`: The list of system monitor events that `Instruments.Sysmon.Reporter` will subscribe to. Defaults to `[]`

For example:

     config :instruments, 
       reporter_module: Instruments.StatsReporter.Logger,
       fast_counter_report_interval: 30_000,
       fast_counter_report_jitter_range: -700..700,
       probe_prefix: "probes",
       statsd_host: "localhost",
       statsd_port: 15339
