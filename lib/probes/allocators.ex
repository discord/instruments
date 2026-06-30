defmodule Instruments.Probes.Allocators do
  @moduledoc """
  A probe that reports per-allocator memory statistics.

  This probe reports three metrics, all derived from `:recon_alloc`:

    * `by_allocator`: the memory allocated by each allocator, as reported by
      `:recon_alloc.memory(:allocated_types)`. A single metric is emitted per
      allocator, tagged with `allocator:<name>`.
    * `backing_carriers`, `backing_carriers_size`: the number of carriers (and
      their total size) allocated by each backing allocator, summed across every
      allocator instance reported by `:recon_alloc.allocators/0`. One metric is
      emitted per backing allocator, tagged with `allocator:<name>` (one of
      `mseg_alloc` or `sys_alloc`).

  To use this probe, register it with the matching keys:

      alias Instruments.{Probe, Probes}
      Probe.define!("recon.alloc.allocated", :gauge,
        module: Probes.Allocators,
        keys: ~w(
          by_allocator
          backing_carriers
          backing_carriers_size
        )a
      )

  All three keys are then reported under `recon.alloc.allocated.<key>`.
  """
  alias Instruments.Probe

  @behaviour Probe

  @backing_allocators ~w(mseg_alloc sys_alloc)a

  # Probe behaviour callbacks

  @doc false
  def probe_init(_name, _type, _options), do: {:ok, nil}

  @doc false
  def probe_sample(state), do: {:ok, state}

  @doc false
  def probe_get_value(_state) do
    {:ok, by_allocator_values() ++ backing_carrier_values()}
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

  defp backing_carrier_values() do
    allocator_infos = Enum.map(:recon_alloc.allocators(), fn {{_name, _}, info} -> info end)

    for backing <- @backing_allocators,
        {key, stat_name} <- [
          backing_carriers: :"#{backing}_carriers",
          backing_carriers_size: :"#{backing}_carriers_size"
        ] do
      sum = compute_sum(allocator_infos, stat_name)
      {key, Probe.Value.new(sum, tags: ["allocator:#{backing}"])}
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
      # The 3-tuple branch isn't currently exercised by the keys in
      # @backing_allocators, but it's left here so the list can be extended as
      # needed. (The 4-tuple branch is used by the *_carriers_size stats.)
      {^stat_name, value, _} -> value
      {^stat_name, value, _, _} -> value
      _other -> 0
    end
  end
end
