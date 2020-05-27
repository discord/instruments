defmodule InstrumentsTest do
  use ExUnit.Case
  import MetricsAssertions

  use Instruments

  setup do
    FakeStatsd.start_link(self())
    :ok
  end

  test "setting a gauge value" do
    Instruments.gauge("foo.bar", 3)
    assert_metric_reported(:gauge, "foo.bar")

    Instruments.gauge("foo.bar", 6, tags: ["my:tag"])
    assert_metric_reported(:gauge, "foo.bar", 6, tags: ["my:tag"])

    Instruments.gauge("foo.bar", 6, tags: ["my:tag"], sample_rate: 1.0)
    assert_metric_reported(:gauge, "foo.bar", 6, tags: ["my:tag"], sample_rate: 1.0)

    gauge_name = "fail_amount"
    Instruments.gauge("foo.bar.#{gauge_name}", 284)
    assert_metric_reported(:gauge, "foo.bar.fail_amount", 284)
  end

  test "incrementing a counter" do
    Instruments.increment("my.counter", 6)
    assert_metric_reported(:increment, "my.counter", 6)

    Instruments.increment("my.counter", 6, tags: ["my:counter_tag"])
    assert_metric_reported(:increment, "my.counter", 6, tags: ["my:counter_tag"])

    Instruments.increment("my.counter", 6, tags: ["my:counter_tag"], sample_rate: 1.0)

    assert_metric_reported(:increment, "my.counter", 6, tags: ["my:counter_tag"], sample_rate: 1.0)

    counter_name = :stinky
    Instruments.increment("my.counter.#{counter_name}", 6)
    assert_metric_reported(:increment, "my.counter.stinky", 6)
  end

  test "decrementing a counter" do
    Instruments.decrement("my.counter", 6)
    assert_metric_reported(:decrement, "my.counter", 6)

    Instruments.decrement("my.counter", 6, tags: ["my:counter_tag"])
    assert_metric_reported(:decrement, "my.counter", 6, tags: ["my:counter_tag"])

    Instruments.decrement("my.counter", 6, tags: ["my:counter_tag"], sample_rate: 1.0)

    assert_metric_reported(:decrement, "my.counter", 6, tags: ["my:counter_tag"], sample_rate: 1.0)

    counter_name = "decrementer"
    Instruments.decrement("my.#{counter_name}.requests", 9)
    assert_metric_reported(:decrement, "my.decrementer.requests", 9)
  end

  test "sending a timing metric" do
    Instruments.timing("my.timer", 3000, sample_rate: 1.0)
    assert_metric_reported(:timing, "my.timer", 3000, sample_rate: 1.0)

    Instruments.timing("my.timer", 3000, tags: ["timing:slow"], sample_rate: 1.0)
    assert_metric_reported(:timing, "my.timer", 3000, tags: ["timing:slow"], sample_rate: 1.0)

    Instruments.timing("my.timer", 3000, tags: ["timing:slow"], sample_rate: 1.0)
    assert_metric_reported(:timing, "my.timer", 3000, tags: ["timing:slow"], sample_rate: 1.0)

    rpc_name = "get_user"
    Instruments.timing("rpc.#{rpc_name}.response_time", 29, sample_rate: 1.0)
    assert_metric_reported(:timing, "rpc.get_user.response_time", 29)
  end

  test "measuring a timed metric" do
    pauser = fn ->
      :timer.sleep(10)
    end

    Instruments.measure("my_timed_metric", [sample_rate: 1.0], pauser)
    assert_metric_reported(:timing, "my_timed_metric", 10..15)

    Instruments.measure("my_timed_metric", [sample_rate: 1.0, tags: ["my:pause"]], pauser)
    assert_metric_reported(:timing, "my_timed_metric", 10..15, tags: ["my:pause"])

    Instruments.measure("my_timed_metric", [tags: ["my:pause"], sample_rate: 1.0], pauser)

    assert_metric_reported(:timing, "my_timed_metric", 10..15,
      tags: ["my:pause"],
      sample_rate: 1.0
    )

    rpc_name = "delete_user"
    Instruments.measure("rpc.#{rpc_name}", [sample_rate: 1.0], pauser)
    assert_metric_reported(:timing, "rpc.delete_user", 10..15)
  end

  test "setting a histogram" do
    Instruments.histogram("my.histogram", 29, sample_rate: 1.0)
    assert_metric_reported(:histogram, "my.histogram", 29)

    Instruments.histogram("my.histogram", 949, tags: ["rpc:call", "other:data"], sample_rate: 1.0)
    assert_metric_reported(:histogram, "my.histogram", 949, tags: ["rpc:call", "other:data"])

    Instruments.histogram("my.histogram", 949, tags: ["rpc:call", "other:data"], sample_rate: 1.0)

    assert_metric_reported(:histogram, "my.histogram", 949,
      tags: ["rpc:call", "other:data"],
      sample_rate: 1.0
    )

    histogram_name = "friend_count"
    Instruments.histogram("discord.users.#{histogram_name}", 29, sample_rate: 1.0)
    assert_metric_reported(:histogram, "discord.users.friend_count", 29)
  end

  test "setting a set value" do
    Instruments.set("my.set", 629)
    assert_metric_reported(:set, "my.set", 629)

    set_name = "custom_set"
    Instruments.set("discord.#{set_name}", 830)
    assert_metric_reported(:set, "discord.custom_set", 830)
  end

  test "sending events" do
    Instruments.send_event("my_title", "my text")

    assert_metric_reported(:event, "my_title", "my text")

    set_name = "dirty"
    Instruments.send_event("my_stuff.#{set_name}", "clothes")
    assert_metric_reported(:event, "my_stuff.dirty", "clothes")
  end

  test "sending events with tags" do
    Instruments.send_event("my_title", "my text", tags: ["host:any", "another:tag"])
    assert_metric_reported(:event, "my_title", "my text", tags: ["host:any", "another:tag"])
  end

  test "sending events with a title that's a variable blows up" do
    quoted =
      quote do
        use Instruments

        val = "43"
        interp = "this is my title #{val}"
        Instruments.send_event(interp, "my_text")
      end

    assert_raise CompileError, ~r/Metric keys must be defined statically/, fn ->
      Code.eval_quoted(quoted)
    end
  end
end
