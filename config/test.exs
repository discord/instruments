use Mix.Config

# setting the statsd port to something other than the default
# in test so we don't conflict in the build env.
config :instruments,
  statsd_port: 15310,
  fast_counter_report_interval: 10,
  reporter_module: Instruments.Statix

config :logger, compile_time_purge_level: :error, level: :error#, backends: []
config :statix, port: 15310
