defmodule Instruments.ProbeTest do
  use ExUnit.Case
  alias Instruments.Probe
  alias Instruments.Probe.Errors.ProbeNameTakenError
  import MetricsAssertions

  setup do
    {:ok, _fake_statsd} = FakeStatsd.start_link(self())

    :ok
  end

  describe "probes with functions" do

    test "it should allow you to define a probe via a function call" do
      Probe.define("other_call", :counter, function: fn -> 3 end,
        report_interval: 20)

      assert_metric_reported(:increment, "other_call", 3)
    end

    test "it should issue a decrement if your function returns a negative value" do
      Probe.define("decrement_call", :counter, function: fn -> -3 end,
        report_interval: 20)

      assert_metric_reported(:decrement, "decrement_call", 3)
    end

    test "it should allow you to select keys from a function call" do
      Probe.define("erlang.memory", :gauge,
        function: fn ->
          [processes: 6, system: 7, atom: 8, binary: 9, ets: 10]
        end,
        keys: ~w(processes system atom binary ets)a,
        report_interval: 20)

      assert_metric_reported(:gauge, "erlang.memory.processes", 6)
      assert_metric_reported(:gauge, "erlang.memory.system", 7)
      assert_metric_reported(:gauge, "erlang.memory.atom", 8)
      assert_metric_reported(:gauge, "erlang.memory.binary", 9)
      assert_metric_reported(:gauge, "erlang.memory.ets", 10)
    end

    test "it should handle :ok tuple values" do
      Probe.define("function.with.ok", :gauge, function: fn -> {:ok, 6} end,
        report_interval: 20)

      assert_metric_reported(:gauge, "function.with.ok", 6)
    end

    test "it should allow flushing" do
      Probe.define("function.with.flush", :gauge, function: fn -> {:ok, 100} end,
        report_interval: 20_000)

      Instruments.flush_all_probes(false)
      assert_metric_reported(:gauge, "function.with.flush", 100)
    end

    test "it should allow the function to return probe results in a keyword list" do
      Probe.define("complex.returns", :gauge,
        function: fn ->
          [with_tags: Probe.Value.new(6, tags: ["my.tag"])]
        end,
        keys: ~w(with_tags)a,
        report_interval: 20)

      assert_metric_reported(:gauge, "complex.returns.with_tags", 6, tags: ["my.tag"],
        sample_rate: 1.0)
    end

    test "it should allow the function to return probe results" do
      Probe.define("overridden.tags", :gauge,
        function: fn ->
          Probe.Value.new(100, tags: ["another.tag"])
        end,
        report_interval: 20)

      assert_metric_reported(:gauge, "overridden.tags", 100, tags: ["another.tag"],
        sample_rate: 1.0)
    end
  end

  describe "probes with mfa" do
    defmodule QuickStaticMetric do
      def probe_value, do: {:ok, 6}
      def error_value, do: {:error, :bad_at_metrics}
      def override_value(arg),
        do: Probe.Value.new(94, tags: ["overridden_tag", "arg_tag.#{arg}"])

      def complex_overrides(state) do
        [clients: Probe.Value.new(state.udp, tags: ["protocol:udp"]),
         clients: Probe.Value.new(state.tcp, tags: ["protocol:tcp"]),
         "clients.udp": state.udp,
         "clients.tcp": state.tcp
        ]
      end
    end

    test "it should allow you to define a probe via mfa" do
      Probe.define("erlang.process_count", :gauge, mfa: {:erlang, :system_info, [:process_count]},
        report_interval: 20)

      assert_metric_reported(:gauge, "erlang.process_count")
    end

    test "it should handle responses with successes" do
      Probe.define("quick.static.metric", :gauge, mfa: {QuickStaticMetric, :probe_value, []},
        report_interval: 20)
      assert_metric_reported(:gauge, "quick.static.metric", 6)
    end

    test "it should allow you to specify options" do
      Probe.define("quick.static.with_options", :histogram, mfa: {QuickStaticMetric, :probe_value, []},
        tags: ["MyTag", "other tag"],
        report_interval: 20)

      assert_metric_reported(:histogram, "quick.static.with_options", 6, [tags: ["MyTag", "other tag"]])
    end

    test "it should allow flushing" do
      Probe.define("quick.static.flush", :gauge, mfa: {QuickStaticMetric, :probe_value, []},
        report_interval: 10_000)

      Instruments.flush_all_probes(false)
      assert_metric_reported(:gauge, "quick.static.flush", 6)
    end

    test "it should allow the mfa to add tags" do
      Probe.define("quick.overridden", :histogram, mfa: {QuickStaticMetric, :override_value, ["great"]},
        tags: ["default_tag"],
        report_interval: 20)

      assert_metric_reported(:histogram, "quick.overridden", 94,
        tags: ["default_tag", "overridden_tag", "arg_tag.great"])
    end

    test "multiple values can be emitted" do
      Probe.define("prefix", :gauge, mfa: {QuickStaticMetric, :complex_overrides, [%{udp: 13, tcp: 128}]},
        keys: [:clients, :"clients.udp", :"clients.tcp"],
        report_interval: 30)

      assert_metric_reported :gauge, "prefix.clients.udp", 13
      assert_metric_reported :gauge, "prefix.clients.tcp", 128

      assert_metric_reported :gauge, "prefix.clients", 13, tags: ["protocol:udp"], sample_rate: 1.0
      assert_metric_reported :gauge, "prefix.clients", 128, tags: ["protocol:tcp"], sample_rate: 1.0
    end
  end

  describe "naming conflicts" do

    test "it should not let you define two probes with the same name" do
      assert_raise ProbeNameTakenError, fn ->
        Probe.define!("foo.bar.baz", :gauge, function: fn -> 3 end)
        Probe.define!("foo.bar.baz", :gauge, function: fn -> 6 end)
      end
    end

    test "it should not let you define two probes that conflict via their keys" do
      assert_raise ProbeNameTakenError, fn ->
        Probe.define!("probe.without.keys", :gauge, function: fn -> 9 end)
        Probe.define!("probe.without", :gauge, function: fn -> [keys: 10, values: 11] end,
          keys: [:keys, :values])
      end
    end
  end

  describe "probes in a module" do
    defmodule ModuleProbe do
      def probe_init(_name, _type, _opts), do: {:ok, 0}
      def probe_get_value(state), do: {:ok, state}
      def probe_reset(_), do: {:ok, 0}
      def probe_sample(state), do: {:ok, state + 1}
      def probe_handle_message(_msg, state), do: {:ok, state}
      def probe_get_datapoints(_), do: [:foo]
    end

    defmodule MessageProbe do
      def probe_init(_name, _type, _opts), do: {:ok, 1}
      def probe_get_value(state), do: {:ok, state}
      def probe_reset(_), do: {:ok, 0}
      def probe_sample(state) do
        send(self(), {:do_update, 6})
        {:ok, state}
      end
      def probe_handle_message({:do_update, val}, _state), do: {:ok, val}
      def probe_handle_message(_msg, state), do: {:ok, state}
      def probe_get_datapoints(_), do: [:foo]
    end

    test "You should be able to define a probe by passing in a module" do
      Probe.define("probe.with.module", :gauge, module: ModuleProbe,
        report_interval: 20)

      assert_metric_reported(:gauge, "probe.with.module")
      assert_metric_reported(:gauge, "probe.with.module")
    end

    test "probes should be able to process messages" do
      Probe.define("probe.with.messages", :gauge, module: MessageProbe,
        report_interval: 20)

      assert_metric_reported(:gauge, "probe.with.messages", 6)
    end

    test "should allow flushing" do
      Probe.define!("probe.with.flush", :gauge, module: MessageProbe,
        report_interval: 10_000) # this shouldn't automatically report

      Instruments.flush_all_probes(false)
      assert_metric_reported(:gauge, "probe.with.flush")
    end
  end

end
