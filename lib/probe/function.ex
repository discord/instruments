defmodule Instruments.Probe.Function do
  @moduledoc false
  @behaviour Instruments.Probe

  def probe_init(_name, _probe_type, options) do
    probe_fn = Keyword.fetch!(options, :function)

    {:ok, {probe_fn, nil}}
  end

  def probe_get_value({_, last_value}) do
    {:ok, last_value}
  end

  def probe_reset({probe_fn, _}) do
    {:ok, {probe_fn, nil}}
  end

  def probe_sample({probe_fn, _}) do
    probe_value =
      case probe_fn.() do
        {:ok, result} -> result
        other -> other
      end

    {:ok, {probe_fn, probe_value}}
  end

  def probe_handle_msg(_, state), do: {:ok, state}
end
