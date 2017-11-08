defmodule Instruments.MacroHelpersTest do
  use ExUnit.Case
  import Instruments.MacroHelpers, only: [to_iolist: 1]

  test "should work with a plain string" do
    assert to_iolist(quote do: "foo.bar.baz") == "foo.bar.baz"
  end

  test "should work with an interpolated string at the end" do
    var = Macro.var(:baz, __MODULE__)
    assert ["foo.bar.", ^var] = to_iolist(quote do: "foo.bar.#{baz}")
  end

  test "should work with an interpolated string in the middle" do
    metric_var = Macro.var(:metric_name, __MODULE__)
    assert ["foo.", ^metric_var, ".bar"] = to_iolist(quote do: "foo.#{metric_name}.bar")
  end


  test "should work with an interpolated string at the beginning" do
    metric_var = Macro.var(:metric_1, __MODULE__)
    assert [^metric_var, ".second"] = to_iolist(quote do: "#{metric_1}.second")
  end

  test "it should work with several interpolated strings" do
    prefix_var = Macro.var(:prefix, __MODULE__)
    suffix_var = Macro.var(:suffix, __MODULE__)

    assert [^prefix_var, ".something.", ^suffix_var] = to_iolist(quote do: "#{prefix}.something.#{suffix}")
  end

  test "it should work with string concatenation" do
    requests_var = Macro.var(:requests, __MODULE__)

    assert [^requests_var, ".suffix"] = to_iolist(quote do: requests <> ".suffix")
  end

  test "it should let you pass in iolists" do
    metric_var = Macro.var(:metric_name, __MODULE__)

    assert ["foo", ".", "bar", ".", "baz"] == to_iolist(quote do: ["foo", ".", "bar", ".", "baz"])
    assert ["foo", ".", "bar", ".", ^metric_var] = to_iolist(quote do: ["foo", ".", "bar", ".", metric_name])
    assert ["foo", ".", ^metric_var, ".", "baz"] = to_iolist(quote do: ["foo", ".", metric_name, ".", "baz"])
    assert [^metric_var, ".", "bar", ".", "baz"] = to_iolist(quote do: [metric_name, ".", "bar", ".", "baz"])
  end

end
