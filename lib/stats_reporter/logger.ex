defmodule Instruments.StatsReporter.Logger do
  @moduledoc """
  A StatsReporter that logs to the `Logger` module.
  """

  @behaviour Instruments.StatsReporter
  require Logger

  @doc false
  def connect(), do: :ok

  @doc false
  def increment(key, value \\ 1, _options \\ []) do
    Logger.info("incrementing #{key} by #{value}")
  end

  @doc false
  def decrement(key, value \\ 1, _options \\ []) do
    Logger.info("decrementing #{key} by #{value}")
  end

  @doc false
  def gauge(key, value, _options \\ []) do
    Logger.info("Setting gauge #{key} to #{value}")
  end

  @doc false
  def histogram(key, value, _options \\ []) do
    Logger.info("Adding #{value} to #{key} histogram")
  end

  @doc false
  def timing(key, value, _options \\ []) do
    Logger.info("#{key} took #{value}ms")
  end

  @doc false
  def measure(key, _options \\ [], fun) do
    {time_in_us, result} = :timer.tc(fun)
    Logger.info("#{key} took #{time_in_us / 1000}ms")
    result
  end

  @doc false
  def set(key, value, _options \\ []) do
    Logger.info("setting #{key} to #{value}")
  end
end
