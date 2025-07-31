use Mix.Config

# setting the statsd port to something other than the default
# in test so we don't conflict in the build env.
config :instruments,
  statsd_port: 15310,
  fast_counter_report_interval: 10,
  fast_counter_report_jitter_range: 0..0,
  fast_gauge_report_interval: 10,
  fast_gauge_report_jitter_range: 0..0,
  rate_tracker_report_interval: 10,
  rate_tracker_report_jitter_range: 0..0,
  reporter_module: Instruments.Statix

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :error]
  ]

config :statix, port: 15310

config :instruments,
  # Don't start the system monitor by default, the tests will start it
  enable_sysmon: false
