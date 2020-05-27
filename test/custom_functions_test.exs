defmodule Instruments.CustomFunctionsTest do
  use ExUnit.Case
  alias Instruments.CustomFunctions
  import MetricsAssertions

  use Instruments

  setup do
    {:ok, _fake_statsd} = FakeStatsd.start_link(self())
    :ok
  end

  defmodule Custom do
    use CustomFunctions, prefix: "custom"
  end

  describe "adding a prefix" do
    test "to increment calls" do
      Custom.increment("foo.bar.baz")
      assert_metric_reported(:increment, "custom.foo.bar.baz", 1)

      Custom.increment("foo.bar.baz", 3)
      assert_metric_reported(:increment, "custom.foo.bar.baz", 3)

      Custom.increment("foo.bar.baz", 4, tags: ["stinky"])
      assert_metric_reported(:increment, "custom.foo.bar.baz", 4, tags: ["stinky"])
    end

    test "to decrement calls" do
      Custom.decrement("foo.bar.bax")
      assert_metric_reported(:decrement, "custom.foo.bar.bax", 1)

      Custom.decrement("foo.bar.bax", 3)
      assert_metric_reported(:decrement, "custom.foo.bar.bax", 3)

      Custom.decrement("foo.bar.baz", 4, tags: ["stinky"])
      assert_metric_reported(:decrement, "custom.foo.bar.baz", 4, tags: ["stinky"])
    end

    test "to gauge calls" do
      Custom.gauge("my.gauge", 384)
      assert_metric_reported(:gauge, "custom.my.gauge", 384)

      Custom.gauge("my.gauge", 946, tags: ["sweet_gauge"])
      assert_metric_reported(:gauge, "custom.my.gauge", 946, tags: ["sweet_gauge"])
    end

    test "to histogram calls" do
      Custom.histogram("my.histogram", 900, sample_rate: 1.0)
      assert_metric_reported(:histogram, "custom.my.histogram", 900)

      Custom.histogram("my.histogram", 901, tags: ["cool_metric"], sample_rate: 1.0)
      assert_metric_reported(:histogram, "custom.my.histogram", 901, tags: ["cool_metric"])
    end

    test "to timing calls" do
      Custom.timing("my.timing", 900, sample_rate: 1.0)
      assert_metric_reported(:timing, "custom.my.timing", 900)

      Custom.timing("my.timing", 901, tags: ["speed:fast"], sample_rate: 1.0)
      assert_metric_reported(:timing, "custom.my.timing", 901, tags: ["speed:fast"])
    end

    test "to set calls" do
      Custom.set("my.set", 900)
      assert_metric_reported(:set, "custom.my.set", 900)

      Custom.set("my.set", 901, tags: ["speed:fast"])
      assert_metric_reported(:set, "custom.my.set", 901, tags: ["speed:fast"])
    end

    test "to measure_calls" do
      func = fn ->
        :timer.sleep(10)
        :done
      end

      assert :done == Custom.measure("my.measure", [sample_rate: 1.0], func)
      assert_metric_reported(:timing, "custom.my.measure", 10..12)

      assert :done ==
               Custom.measure("my.measure", [sample_rate: 1.0, tags: ["timing:short"]], func)

      assert_metric_reported(:timing, "custom.my.measure", 10..11, tags: ["timing:short"])
    end
  end

  test "setting a runtime prefix" do
    defmodule RuntimePrefix do
      use CustomFunctions, prefix: Application.get_env(:instruments, :custom_prefix, "foobar")
    end

    RuntimePrefix.increment("foo.bar", 3)
    assert_metric_reported(:increment, "foobar.foo.bar", 3)
  end
end
