defmodule Instruments.StatsReporter.Null do
  @moduledoc """
  A StatsReporter module that throws out all logging messages.
  """

  @behaviour Instruments.StatsReporter

  @doc false
  def connect(), do: :ok

  @doc false
  def increment(_key, _value \\ 1, _options \\ []), do: :ok

  @doc false
  def decrement(_key, _value \\ 1, _options \\ []), do: :ok

  @doc false
  def gauge(_key, _value, _options \\ []), do: :ok

  @doc false
  def histogram(_key, _value, _options \\ []), do: :ok

  @doc false
  def timing(_key, _value, _options \\ []), do: :ok

  @doc false
  def measure(_key, _options \\ [], fun), do: fun.()

  @doc false
  def set(_key, _value, _options \\ []), do: :ok
end
