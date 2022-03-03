defmodule Instruments.Probes.Schedulers do
  @moduledoc """
  A probe that reports erlang's internal CPU usage

  Any good system monitoring needs to understand how hard the CPU is working. In
  an Erlang ecosystem, this can be somewhat challenging becase when an Erlang
  system isn't busy, the BEAM vm keeps its schedulers in tight loops so they don't get
  descheduled by the operating system. This can make external CPU metrics like `top`
  report that the system is actually much busier than it is.

  This module reports Erlang's internal view of its scheduler utilization and is
  a better gauge of how loaded your system is. It reports two values, the total
  utilization, and a [weighted utilization](http://erlang.org/doc/man/erlang.html#statistics_scheduler_wall_time),
  which can be used as a proxy for CPU usage.

  To use this probe, add the following function somewhwere in your application's
  initialization:

      alias Instruments
      Probe.define!("erlang.scheduler_utilization", :gauge, module: Probes.Schedulers, keys: ~w(weighted total))

  The probe will now report two metrics, `erlang.scheduler_utilization.total` and `erlang.scheduler_utilization.total`.
  """
  alias Instruments.Probe

  @behaviour Probe

  # Probe behaviour callbacks

  @doc false
  def behaviour(), do: :probe

  @doc false
  def probe_init(_name, _type, _options) do
    :erlang.system_flag(:scheduler_wall_time, true)
    wall_time = calculate_wall_time()
    {:ok, %{wall_time: wall_time, old_wall_time: wall_time}}
  end

  @doc false
  def probe_get_value(%{wall_time: new_wall_time, old_wall_time: old_wall_time}) do
    {active, total} =
      old_wall_time
      |> Enum.zip(new_wall_time)
      |> Enum.reduce({0, 0}, fn {{_, old_active, old_total}, {_, new_active, new_total}},
                                {active, total} ->
        {active + (new_active - old_active), total + (new_total - old_total)}
      end)

    # this alogrithm taken from http://erlang.org/doc/man/erlang.html#statistics_scheduler_wall_time
    stats =
      case total do
        0 ->
          [weighted: 0.0, total: 0.0]

        _ ->
          total_scheduler_utilization = active / total

          weighted_utilization =
            total_scheduler_utilization * total_scheduler_count() / logical_processor_count()

          weighted_utilization_percent = Float.round(weighted_utilization * 100, 3)

          [
            weighted: weighted_utilization_percent,
            total: Float.round(total_scheduler_utilization * 100, 3)
          ]
      end

    {:ok, stats}
  end

  @doc false
  def probe_reset(state), do: {:ok, state}

  @doc false
  def probe_sample(%{wall_time: old_wall_time} = state) do
    {:ok, %{state | old_wall_time: old_wall_time, wall_time: calculate_wall_time()}}
  end

  @doc false
  def probe_handle_message(_, state), do: {:ok, state}

  # end probe behaviour callbacks

  # Private
  defp calculate_wall_time() do
    :scheduler_wall_time
    |> :erlang.statistics()
    |> Enum.sort()
  end

  defp total_scheduler_count() do
    :erlang.system_info(:schedulers) + dirty_scheduler_count()
  end

  defp dirty_scheduler_count() do
    try do
      :erlang.system_info(:dirty_cpu_schedulers)
    rescue
      ArgumentError ->
        0
    end
  end

  defp logical_processor_count() do
    case :erlang.system_info(:logical_processors_available) do
      :unknown ->
        :erlang.system_info(:logical_processors_online)

      proc_count when is_integer(proc_count) ->
        proc_count
    end
  end
end
