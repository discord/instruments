ExUnit.start()

defmodule MetricsAssertions do
  @safe_metric_types [:increment, :decrement, :gauge, :event, :set]
  use ExUnit.Case

  def assert_metric_reported(metric_type, metric_name) do
    assert_receive {:metric_reported, {^metric_type, ^metric_name, _, _}}
  end
  def assert_metric_reported(metric_type, metric_name, metric_value) when is_number(metric_value) do
    assert_receive {:metric_reported, {^metric_type, ^metric_name, ^metric_value, _}}
  end
  def assert_metric_reported(metric_type, metric_name, expected_metric_value)  do
    assert_receive {:metric_reported, {^metric_type, ^metric_name, actual_value, _}}
    cond do
      Range.range?(expected_metric_value) ->
        do_assert_range(expected_metric_value, actual_value)

      true ->
        assert expected_metric_value == actual_value
    end
  end
  def assert_metric_reported(metric_type, metric_name, metric_value, options) when is_number(metric_value) do

    assert_receive {:metric_reported, {^metric_type, ^metric_name, ^metric_value, actual_options}}

    do_assert_options(metric_type, options, actual_options)
  end
  def assert_metric_reported(metric_type, metric_name, expected_metric_value, options) do
    assert_receive {:metric_reported, {^metric_type, ^metric_name, actual_metric_value, actual_options}}

    do_assert_options(metric_type, options, actual_options)
    cond do
      Range.range?(expected_metric_value) ->
        do_assert_range(expected_metric_value, actual_metric_value)

      true ->
        assert expected_metric_value == actual_metric_value
    end
  end

  defp do_assert_range(metric_range, actual_metric_value) do
    assert round(actual_metric_value) in metric_range
  end

  defp do_assert_options(metric_type, expected, actual) when metric_type in @safe_metric_types,
    do: assert expected == actual

  defp do_assert_options(_, expected_options, actual_options) do
    options_with_sample_rate = Keyword.merge([sample_rate: 1.0], expected_options)
    for {expected_key, expected_value} <- options_with_sample_rate do
      assert {expected_key, expected_value} == {expected_key, Keyword.get(actual_options, expected_key)}
    end
  end
end
