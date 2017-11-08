defmodule Instruments.StatsReporter do
  @moduledoc """
  A behavoiur for reporters.

  Reporters emit values back to the underlying reporting system.
  Out of the box, Instruments provides `Instruments.Statix`, `Instruments.StatsReporter.Logger`,
  and `Instruments.StatsReporter.Null`reporters.
  """

  @type key :: String.t
  @type stats_return :: :ok | {:error, term}

  @doc """
  Connect to the reporter.
  This function is called by the system prior to using the reporter,
  any connections should be established in this function.
  """
  @callback connect() :: :ok

  @doc """
  Increment a key by the specified value
  """
  @callback increment(key, integer, keyword) :: stats_return

  @doc """
  Decrement a key by the specified value
  """
  @callback decrement(key, integer, keyword) :: stats_return

  @doc """
  Set the value of the key to the specified value
  """
  @callback gauge(key, integer, keyword) :: stats_return

  @doc """
  Include the value in the histogram defined by `key`
  """
  @callback histogram(key, integer, keyword) :: stats_return

  @doc """
  Include the timing in the `key`
  """
  @callback timing(key, integer, keyword) :: stats_return

  @doc """
  Measure the execution time of the provided function and
  include it in the metric defined by `key`
  """
  @callback measure(key, keyword, (() -> any)) :: any

  @doc """
  Write the value into the set defined by `key`
  """
  @callback set(key, integer, keyword) :: stats_return
end
