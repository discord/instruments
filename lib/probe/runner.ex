defmodule Instruments.Probe.Runner do
  @moduledoc false

  # A module tasked with running probes.
  # This module is a controller process for running module-based probes.
  # It periodically exectues callback functions on the probes, and reports their
  # results to statix.

  defmodule State do
    @moduledoc false

    @type t :: %{
            name: String.t(),
            datapoints: [atom],
            reporter_options: Instruments.Probe.probe_options(),
            report_integer: pos_integer,
            sample_interval: pos_integer,
            probe_module: module,
            probe_state: any
          }

    defstruct name: nil,
              type: nil,
              datapoints: %{},
              reporter_module: nil,
              reporter_options: [],
              report_interval: 1_000,
              sample_interval: 1_000,
              probe_module: nil,
              probe_state: nil

    def new(metric_name, type, options, probe_module) do
      report_interval = Keyword.get(options, :report_interval, 10_000)
      sample_interval = Keyword.get(options, :sample_interval, report_interval)

      datapoints =
        if Keyword.has_key?(options, :keys) do
          for key <- Keyword.get(options, :keys), into: %{} do
            {key, "#{metric_name}.#{key}"}
          end
        else
          %{metric_name => metric_name}
        end

      %__MODULE__{
        name: metric_name,
        type: type,
        datapoints: datapoints,
        reporter_module: Application.get_env(:instruments, :reporter_module, Instruments.Statix),
        report_interval: report_interval,
        sample_interval: sample_interval,
        probe_module: probe_module,
        reporter_options: sanitize_reporter_options(options)
      }
    end

    defp sanitize_reporter_options(options) do
      [sample_rate: 1.0]
      |> Keyword.merge(options)
      |> Keyword.take([:sample_rate, :tags])
    end
  end

  alias Instruments.Probe
  use GenServer
  require Logger

  @spec start_link(String.t(), Probe.probe_type(), Probe.probe_options(), module) :: {:ok, pid}
  def start_link(name, type, options, probe_module) do
    start_link({name, type, options, probe_module})
  end

  @spec start_link({String.t(), Probe.probe_type(), Probe.probe_options(), module}) :: {:ok, pid}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def flush(probe_pid) do
    GenServer.call(probe_pid, :flush)
  end

  def init({name, type, options, probe_module}) do
    state = State.new(name, type, options, probe_module)
    {:ok, probe_state} = probe_module.probe_init(name, type, options)
    Process.send_after(self(), :probe_sample, state.sample_interval)
    Process.send_after(self(), :probe_update, state.report_interval)

    {:ok, %State{state | probe_state: probe_state}}
  end

  def handle_call(:flush, _from, %State{} = state) do
    {:ok, new_probe_state} = state.probe_module.probe_sample(state.probe_state)
    new_state = %State{state | probe_state: new_probe_state}
    do_probe_update(new_state)

    {:reply, :ok, new_state}
  end

  def handle_info(:probe_sample, %State{} = state) do
    {:ok, new_probe_state} = state.probe_module.probe_sample(state.probe_state)
    Process.send_after(self(), :probe_sample, state.sample_interval)

    {:noreply, %State{state | probe_state: new_probe_state}}
  end

  def handle_info(:probe_update, %State{} = state) do
    do_probe_update(state)

    Process.send_after(self(), :probe_update, state.report_interval)
    {:noreply, state}
  end

  def handle_info(unknown_message, %{} = state) do
    {:ok, new_probe_state} =
      state.probe_module.probe_handle_message(unknown_message, state.probe_state)

    {:noreply, %State{state | probe_state: new_probe_state}}
  end

  # Private

  defp do_probe_update(%State{} = state) do
    {:ok, values} = state.probe_module.probe_get_value(state.probe_state)

    case values do
      %Probe.Value{} = value ->
        Enum.each(state.datapoints, fn {_, metric_name} ->
          send_metric(metric_name, value, state)
        end)

      values when is_list(values) ->
        Enum.each(state.datapoints, fn {key, metric_name} ->
          values
          |> Keyword.get_values(key)
          |> Enum.each(&send_metric(metric_name, &1, state))
        end)

      value when is_number(value) ->
        Enum.each(state.datapoints, fn {_, metric_name} ->
          send_metric(metric_name, value, state)
        end)

      nil ->
        Logger.info("Not Sending #{state.name} due to nil return")

      invalid ->
        Logger.warn("Probe #{state.name} has returned an invalid value: #{inspect(invalid)}")
    end
  end

  defp send_metric(_metric_name, 0, %State{type: :counter}),
    do: :ok

  defp send_metric(metric_name, metric_value, %State{type: :counter} = state)
       when metric_value > 0 do
    send_metric(metric_name, metric_value, %State{state | type: :increment})
  end

  defp send_metric(metric_name, metric_value, %State{type: :counter} = state)
       when metric_value < 0 do
    send_metric(metric_name, abs(metric_value), %State{state | type: :decrement})
  end

  defp send_metric(
         metric_name,
         %Probe.Value{value: value, tags: tags, sample_rate: sample_rate},
         %State{} = state
       ) do
    tags =
      case tags do
        tags when is_list(tags) ->
          Keyword.get(state.reporter_options, :tags, []) ++ tags

        _ ->
          Keyword.get(state.reporter_options, :tags, [])
      end

    sample_rate =
      case sample_rate do
        sample_rate when is_float(sample_rate) ->
          sample_rate

        _ ->
          Keyword.get(state.reporter_options, :sample_rate, 1.0)
      end

    new_opts = Keyword.merge(state.reporter_options, tags: tags, sample_rate: sample_rate)
    send_metric(metric_name, value, %State{state | reporter_options: new_opts})
  end

  defp send_metric(metric_name, metric_value, %State{} = state) when is_number(metric_value) do
    :erlang.apply(state.reporter_module, state.type, [
      metric_name,
      metric_value,
      state.reporter_options
    ])

    :ok
  end

  defp send_metric(_metric_name, _metric_value, _state),
    do: :ok
end
