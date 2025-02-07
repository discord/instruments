defmodule Instruments.EmitterTest do
  use ExUnit.Case

  alias Instruments.Sysmon.Emitter
  alias Instruments.Sysmon.Reporter

  defmodule TestEmitter do
    @behaviour Instruments.Sysmon.Receiver

    @impl true
    def handle_busy_dist_port(pid, port) do
      send(TestEmitterReceiver, {:busy_dist_port, pid, port})
    end

    @impl true
    def handle_busy_port(pid, port) do
      send(TestEmitterReceiver, {:busy_port, pid, port})
    end

    @impl true
    def handle_long_gc(pid, info) do
      send(TestEmitterReceiver, {:long_gc, pid, info})
    end

    @impl true
    def handle_long_message_queue(pid, long) do
      send(TestEmitterReceiver, {:long_message_queue, pid, long})
    end

    @impl true
    def handle_long_schedule(pid, info) do
      send(TestEmitterReceiver, {:long_schedule, pid, info})
    end

    @impl true
    def handle_large_heap(pid, info) do
      send(TestEmitterReceiver, {:large_heap, pid, info})
    end
  end

  setup do
    Process.register(self(), TestEmitterReceiver)
    Application.put_env(:instruments, :sysmon_receiver, TestEmitter)

    start_link_supervised!(Reporter)
    pid = start_link_supervised!(Emitter)

    {:ok, pid: pid}
  end

  test "handle_busy_dist_port", ctx do
    pid = self()
    port = :erlang.list_to_port(~c"#Port<0.1>")
    send(ctx.pid, {Reporter, :busy_dist_port, %{pid: pid, port: port}})
    assert_receive {:busy_dist_port, ^pid, ^port}
  end

  test "handle_busy_port", ctx do
    pid = self()
    port = :erlang.list_to_port(~c"#Port<0.1>")
    send(ctx.pid, {Reporter, :busy_port, %{pid: pid, port: port}})
    assert_receive {:busy_port, ^pid, ^port}
  end

  test "handle_long_gc", ctx do
    pid = self()
    send(ctx.pid, {Reporter, :long_gc, %{
      pid: pid,
      info: []
    }})
    assert_receive {:long_gc, ^pid, []}
  end

  test "handle_long_message_queue", ctx do
    pid = self()
    send(ctx.pid, {Reporter, :long_message_queue, %{
      pid: pid,
      info: true
    }})
    assert_receive {:long_message_queue, ^pid, true}
  end

  test "handle_long_schedule", ctx do
    pid = self()
    send(ctx.pid, {Reporter, :long_schedule, %{
      pid: pid,
      info: []
    }})
    assert_receive {:long_schedule, ^pid, []}
  end

  test "handle_large_heap", ctx do
    pid = self()
    send(ctx.pid, {Reporter, :large_heap, %{
      pid: pid,
      info: []
    }})
    assert_receive {:large_heap, ^pid, []}
  end

end
