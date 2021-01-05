defmodule Instruments.Probe do
  @moduledoc """
  A behavior for a Probe.

  Modules that define probes are expected to implement all of the functions in
  this behaviour.

  A probe is created via the call to `c:Instruments.Probe.probe_init/3`, and is
  then called every `sample_interval` milliseconds via the
  `c:Instruments.Probe.probe_sample/1` function. The probe can then update its
  internal state and do any processing it requires.

  Every `report_interval` milliseconds, the probe is expected to emit its metric
  value.

  """

  @type datapoint :: String.t()
  @type state :: any
  @type probe_value :: number | keyword
  @type probe_type :: :counter | :spiral | :gauge | :histogram | :timing | :set
  @type probe_options :: [
          {:sample_rate, pos_integer}
          | {:tags, [String.t(), ...]}
          | {:report_interval, pos_integer}
          | {:sample_interval, pos_integer}
          | {:function, (() -> {:ok, state})}
          | {:mfa, {module(), atom(), [term()]}}
          | {:module, module}
          | {:keys, [atom]}
        ]

  @doc """
  Called when the probe is created. The callback is passed
  the name of the probe, what kind of metric it's producing and the options
  the probe was created with.

  You must return `{:ok, state}`. The state will be passed back to you on
  subsequent callbacks. Any other return values will cancel further
  execution of the probe.
  """
  @callback probe_init(String.t(), probe_type, probe_options) :: {:ok, state}

  @doc """
  Called every `sample_interval` milliseconds. When called, the probe should
  perform its measurement and update its internal state.

  You must return `{:ok, state}`. Any other return values will cancel further
  execution of the probe.
  """
  @callback probe_sample(state) :: {:ok, state}

  @doc """
  Called at least every `report_interval` milliseconds. This call reads the
  value of the probe, which is reported to the underlying statistics system.

  Return values can either take the form of a single numeric value, or a
  keyword list keys -> numeric values. Nil values won't be reported to the
  statistics system.
  """
  @callback probe_get_value(state) :: {:ok, probe_value}

  @doc """
  Resets the probe's state.

  You must return `{:ok, state}`. Any other return values will cancel further
  execution of the probe.
  """
  @callback probe_reset(state) :: {:ok, state}

  @doc """
  Called when the probe's runner process receives an unknown message.

  You must return `{:ok, state}`. Any other return values will cancel further
  execution of the probe.
  """
  @callback probe_handle_message(any, state) :: {:ok, state}

  alias Instruments.Probe.Definitions

  defdelegate define(name, type, options), to: Definitions
  defdelegate define!(name, type, options), to: Definitions
end
