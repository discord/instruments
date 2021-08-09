defmodule Instruments.Probe.Definitions do
  @moduledoc false

  use GenServer
  alias Instruments.Probe
  alias Instruments.Probe.Errors

  @type definition_errors :: {:error, {:probe_names_taken, [String.t()]}}
  @type definition_response :: {:ok, [String.t()]} | definition_errors

  @probe_prefix Application.get_env(:instruments, :probe_prefix)
  @table_name :probe_definitions

  def start_link(_ \\ []), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    table_name = @table_name
    ^table_name = :ets.new(table_name, [:named_table, :set, :protected, read_concurrency: true])
    {:ok, nil}
  end

  @doc """
  Defines a probe. If the definition fails, an exception is thrown.
  @see define/3
  """
  @spec define!(String.t(), Probe.probe_type(), Probe.probe_options()) :: [String.t()]
  def define!(name, type, options) do
    case define(name, type, options) do
      {:ok, probe_names} ->
        probe_names

      {:error, {:probe_names_taken, taken_names}} ->
        raise Errors.ProbeNameTakenError.exception(taken_names: taken_names)
    end
  end

  @doc """
  Defines a probe.
  The probe type can be:

    * `gauge`: A single emitted value
    * `counter`: A value that's incremented or decremeted over time.
       If the value is negative, a decrement command is issued,
       otherwise an increment command is executed.
    * `histogram`: A value combined into a series and then listed as percentages.
    * `timing`: A millisecond timing value.

  Returns `{:ok, [probe_name]}` or `{:error, reason}`.
  """
  @spec define(String.t(), Probe.probe_type(), Probe.probe_options()) :: definition_response
  def define(base_name, type, options) do
    name = to_probe_name(@probe_prefix, base_name)

    defn_fn = fn ->
      cond do
        Keyword.has_key?(options, :function) ->
          Probe.Supervisor.start_probe(name, type, options, Probe.Function)

        Keyword.has_key?(options, :mfa) ->
          {{module, fun, args}, options} = Keyword.pop(options, :mfa)
          probe_fn = fn -> :erlang.apply(module, fun, args) end
          options = Keyword.put(options, :function, probe_fn)

          Probe.Supervisor.start_probe(name, type, options, Probe.Function)

        Keyword.has_key?(options, :module) ->
          probe_module = Keyword.get(options, :module)
          Probe.Supervisor.start_probe(name, type, options, probe_module)
      end
    end

    definitions =
      case Keyword.get(options, :keys) do
        keys when is_list(keys) ->
          Enum.map(keys, fn key -> "#{name}.#{key}" end)

        nil ->
          [name]
      end

    unique_names = unique_names(definitions, options)

    GenServer.call(__MODULE__, {:define, unique_names, defn_fn})
  end

  def handle_call({:define, probe_names, transaction}, _from, _) do
    response =
      case used_probe_names(probe_names) do
        [] ->
          added_probes =
            Enum.map(probe_names, fn probe_name ->
              true = :ets.insert_new(@table_name, {probe_name, probe_name})
              probe_name
            end)

          transaction.()
          {:ok, added_probes}

        used_probe_names ->
          {:error, {:probe_names_taken, used_probe_names}}
      end

    {:reply, response, nil}
  end

  @spec unique_names([String.t()], Probe.probe_options()) :: [String.t()]
  defp unique_names(probe_names, options) do
    case Keyword.get(options, :tags) do
      tags when is_list(tags) ->
        tag_string = Enum.join(Enum.sort(tags), ",")
        for probe_name <- probe_names do
          "#{probe_name}.tags:#{tag_string}"
        end

      nil ->
        probe_names
    end
  end

  @spec used_probe_names([String.t()]) :: [String.t()]
  defp used_probe_names(probe_names) do
    probe_names
    |> Enum.map(&:ets.match(@table_name, {&1, :"$1"}))
    |> List.flatten()
  end

  def to_probe_name(nil, base_name), do: base_name
  def to_probe_name(probe_prefix, base_name), do: "#{probe_prefix}.#{base_name}"
end
