defmodule FakeStatsd do
  @moduledoc """
  A fake stats server.

  This statsd server will parse incoming statsd calls and forward them to the process
  send into its start_link function.
  """
  use GenServer

  def start_link(test_process) do
    GenServer.start_link(__MODULE__, [test_process], name: __MODULE__)
  end

  def init([test_process]) do
    {:ok, sock} = :gen_udp.open(Instruments.statsd_port(), [:binary, active: true, reuseaddr: true])
    {:ok, {test_process, sock}}
  end

  def handle_info({:udp, socket, _ip, _port_info, packet}, {test_process, socket}) do
    send(test_process, {:metric_reported, decode(packet)})

    {:noreply, {test_process, socket}}
  end

  defp decode(packet_bytes) do
    packet_bytes
    |> String.split("|")
    |> do_decode
  end

  defp do_decode([name_and_val, type | rest]) do
    opts = decode_tags_and_sampling(rest)
    {name, val} = decode_name_and_value(name_and_val)
    do_decode(name, val, type, opts)
  end

  defp do_decode(name, val, "g", opts) do
    {:gauge, name, to_number(val), opts}
  end

  defp do_decode(name, val, "ms", opts) do
    {:timing, name, to_number(val), opts}
  end

  defp do_decode(name, val, "s", opts) do
    {:set, name, to_number(val), opts}
  end

  defp do_decode(name, val, "h", opts) do
    {:histogram, name, to_number(val), opts}
  end

  defp do_decode(name, val, "c", opts) do
    {type, numeric_val} =
      case to_number(val) do
        v when v >= 0 ->
          {:increment, v}

        v ->
          {:decrement, -v}
      end

    {type, name, numeric_val, opts}
  end

  defp do_decode(:event, name, val, opts) do
    {:event, name, val, opts}
  end

  defp decode_tags_and_sampling(tags_and_sampling),
    do: decode_tags_and_sampling(tags_and_sampling, [])

  defp decode_tags_and_sampling([], accum) do
    accum
  end

  defp decode_tags_and_sampling([<<"#", tags::binary>> | rest], accum) do
    tag_list = String.split(tags, ",")
    decode_tags_and_sampling(rest, Keyword.put(accum, :tags, tag_list))
  end

  defp decode_tags_and_sampling([<<"@", sampling::binary>> | rest], accum) do
    sample_rate = String.to_float(sampling)
    decode_tags_and_sampling(rest, Keyword.put(accum, :sample_rate, sample_rate))
  end

  defp decode_name_and_value(<<"_e", rest::binary>>) do
    [_lengths, title] = String.split(rest, ":")

    {:event, title}
  end

  defp decode_name_and_value(name_and_val) do
    [name, value] = String.split(name_and_val, ":")
    {name, value}
  end

  defp to_number(s) do
    with {int_val, ""} <- Integer.parse(s) do
      int_val
    else
      _ ->
        case Float.parse(s) do
          {float_val, ""} ->
            float_val

          _ ->
            s
        end
    end
  end
end
