defmodule Instruments.Probes.Allocators do
  @moduledoc """
  A probe that reports per-allocator memory statistics.

  This probe reports five metrics, all derived from `:recon_alloc`:

    * `by_allocator`: the memory used by each allocated type, as reported by
      `:recon_alloc.memory(:allocated_types)`. A single metric is emitted per
      allocator, tagged with `allocator:<name>`.
    * `mseg_alloc_carriers_size`, `sys_alloc_carriers_size`,
      `mseg_alloc_carriers`, `sys_alloc_carriers`: the sum of the corresponding
      carrier statistic across every allocator instance reported by
      `:recon_alloc.allocators/0`.

  To use this probe, register it with the matching keys:

      alias Instruments.{Probe, Probes}
      Probe.define!("recon.alloc.allocated", :gauge,
        module: Probes.Allocators,
        keys: ~w(
          by_allocator
          mseg_alloc_carriers_size
          sys_alloc_carriers_size
          mseg_alloc_carriers
          sys_alloc_carriers
        )a
      )

  All five keys are then reported under `recon.alloc.allocated.<key>`.
  """
  alias Instruments.Probe

  @behaviour Probe

  @carrier_stats ~w(
    mseg_alloc_carriers_size
    sys_alloc_carriers_size
    mseg_alloc_carriers
    sys_alloc_carriers
  )a

  # Probe behaviour callbacks

  @doc false
  def probe_init(_name, _type, _options), do: {:ok, nil}

  @doc false
  def probe_sample(state), do: {:ok, state}

  @doc false
  def probe_get_value(_state) do
    {:ok, by_allocator_values() ++ carrier_sum_values()}
  end

  @doc false
  def probe_reset(state), do: {:ok, state}

  @doc false
  def probe_handle_message(_, state), do: {:ok, state}

  # end probe behaviour callbacks

  # Private

  defp by_allocator_values() do
    Enum.map(
      :recon_alloc.memory(:allocated_types),
      fn {allocator, size} ->
        {:by_allocator, Probe.Value.new(size, tags: ["allocator:#{allocator}"])}
      end
    )
  end

  defp carrier_sum_values() do
    allocator_infos = Enum.map(:recon_alloc.allocators(), fn {{_name, _}, info} -> info end)

    for stat_name <- @carrier_stats do
      {stat_name, compute_sum(allocator_infos, stat_name)}
    end
  end

  # sums all items with the specified stat name (from all groups).
  defp compute_sum(items, stat_name) when is_list(items) do
    items
    |> Enum.map(fn item -> compute_sum(item, stat_name) end)
    |> Enum.sum()
  end

  defp compute_sum({_group, items}, stat_name) when is_list(items) do
    compute_sum(items, stat_name)
  end

  defp compute_sum(item, stat_name) do
    case item do
      {^stat_name, value} -> value
      # Technically these last two branches aren't used for the keys in
      # @carrier_stats, but I have left them so we can extend that list as
      # needed.
      {^stat_name, value, _} -> value
      {^stat_name, value, _, _} -> value
      _other -> 0
    end
  end
end
