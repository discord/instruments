defmodule Instruments.Sysmon.ReporterTest do
  use ExUnit.Case

  alias Instruments.Sysmon.Reporter

  describe "subscriptions" do
    setup do
      {:ok, reporter_pid} = start_supervised(Reporter)
      Process.link(reporter_pid)

      {:ok, %{
        reporter_pid: reporter_pid
      }}
    end

    test "allows subscribing", ctx do
      :ok = Reporter.subscribe()
      state = :sys.get_state(ctx.reporter_pid)
      assert Map.values(state.subscribers) == [self()]
    end

    test "can subscribe more than once", ctx do
      :ok = Reporter.subscribe()
      :ok = Reporter.subscribe()
      state = :sys.get_state(ctx.reporter_pid)
      assert Map.values(state.subscribers) == [self()]
    end

    test "allows unsubscribing", ctx do
      :ok = Reporter.subscribe()
      :ok = Reporter.unsubscribe()
      state = :sys.get_state(ctx.reporter_pid)
      assert Map.values(state.subscribers) == []
    end

    test "sends events to subscribers" do
      Reporter.subscribe()
      dummy_port = :erlang.list_to_port(~c"#Port<0.1>")
      pid = self()
      send(Reporter, {:monitor, pid, :busy_port, dummy_port})
      assert_receive {Reporter, :busy_port, %{pid: ^pid, port: ^dummy_port}}
    end
  end

  describe "events" do

    test "can be set from environment" do
      prev = Application.get_env(:instruments, :sysmon_events)
      on_exit(fn ->
        Application.put_env(:instruments, :sysmon_events, prev)
      end)
      Application.put_env((:instruments), :sysmon_events, [:busy_port, :busy_dist_port])
      {:ok, pid} = start_supervised(Reporter)
      Process.link(pid)

      assert Reporter.get_events() == [:busy_port, :busy_dist_port]
      assert :erlang.system_monitor() == {pid, [:busy_dist_port, :busy_port]}
    end

    test "can be reconfigured" do
      {:ok, pid} = start_supervised(Reporter)
      Process.link(pid)

      Reporter.set_events([:busy_port, :busy_dist_port])
      assert :erlang.system_monitor() == {pid, [:busy_dist_port, :busy_port]}
    end

  end
end
