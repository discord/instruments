defmodule Instruments.RateTrackerTest do
  use ExUnit.Case

  alias Instruments.RateTracker

  setup do
    old_threshold = Application.get_env(:instruments, :rate_tracker_callback_threshold)
    Application.put_env(:instruments, :rate_tracker_callback_threshold, 5)

    on_exit(fn ->
      if old_threshold do
        Application.put_env(:instruments, :rate_tracker_callback_threshold, old_threshold)
      else
        Application.delete_env(:instruments, :rate_tracker_callback_threshold)
      end
    end)

    :ok
  end

  test "calls callback if rate is exceeded" do
    me = self()

    RateTracker.subscribe(fn value, _rate ->
      send(me, value)
    end)

    Enum.each(
      1..1000,
      fn _n ->
        RateTracker.track("test.metric", tags: ["test_tag_1:abc", "test_tag_2:def"])
      end
    )

    assert_receive {"test.metric", [tags: ["test_tag_1:abc", "test_tag_2:def"]]}
  end

  test "does not call calback if rate not exceeded" do
    me = self()

    RateTracker.subscribe(fn value, _rate ->
      send(me, value)
    end)

    refute_receive {"test.metric", [tags: ["test_tag_1:abc", "test_tag_2:def"]]}
  end

  test "a highly frequent but low sampled metric won't be reported" do
    me = self()

    Enum.each(
      1..1000,
      fn _n ->
        RateTracker.track("test.metric", tags: ["test_tag_1:abc", "test_tag_2:def"], sample_rate: 0.001)
      end
    )

    RateTracker.subscribe(fn value, _rate ->
      send(me, value)
    end)

    refute_receive {"test.metric", [tags: ["test_tag_1:abc", "test_tag_2:def"]]}
  end
end
