defmodule Instruments.MacroHelpers do
  @moduledoc false

  alias Instruments.RateTracker

  @safe_metric_types [:increment, :decrement, :gauge, :event, :set]

  @metrics_module Application.get_env(:instruments, :reporter_module, Instruments.Statix)

  def build_metric_macro(:measure, caller, metrics_module, key_ast, options_ast, function) do
    key = to_iolist(key_ast, caller)

    quote do
      safe_opts = unquote(to_safe_options(:measure, options_ast))
      Instruments.MacroHelpers.maybe_track(unquote(key), unquote(metrics_module), safe_opts)
      unquote(metrics_module).measure(unquote(key), safe_opts, unquote(function))
    end
  end

  def build_metric_macro(type, caller, metrics_module, key_ast, value_ast, options_ast) do
    key = to_iolist(key_ast, caller)

    quote do
      safe_opts = unquote(to_safe_options(type, options_ast))
      Instruments.MacroHelpers.maybe_track(unquote(key), unquote(metrics_module), safe_opts)
      unquote(metrics_module).unquote(type)(unquote(key), unquote(value_ast), safe_opts)
    end
  end

  @doc """
  Transforms metric keys into iolists. A metric key can be:

    * A list, in which case it's let through unchanged
    * A static bitstring, which is let through unchanged
    * An interpolated bitstring, which is converted to an iolist
      where the interpolated variables are members
    * A concatenation operation, which is handled like an interpolated
      bitstring
  """
  def to_iolist({var_name, [line: line], mod}, caller) when is_atom(var_name) and is_atom(mod) do
    raise CompileError,
      description: "Metric keys must be defined statically",
      line: line,
      file: caller.file
  end

  def to_iolist(metric, _) when is_bitstring(metric),
    do: metric

  def to_iolist(metric, _) when is_list(metric) do
    metric
  end

  def to_iolist(metric, _) do
    {_t, iolist} = Macro.postwalk(metric, [], &parse_iolist/2)

    Enum.reverse(iolist)
  end

  # Track if we're using a non-Fast* module.
  def maybe_track(key, @metrics_module, opts) do
    RateTracker.track(key, opts)
  end

  def maybe_track(_key, _module, _opts) do
    :ok
  end

  # Parses string literals
  defp parse_iolist(string_literal = ast, acc) when is_bitstring(string_literal),
    do: {ast, [string_literal | acc]}

  # This handles the `Kernel.to_string` call that string interpolation emits
  defp parse_iolist({{:., _ctx, [Kernel, :to_string]}, _, [_var]} = to_string_call, acc),
    do: {nil, [to_string_call | acc]}

  # this head handles string concatenation with <>
  defp parse_iolist({:<>, _, [left, right]}, _) do
    # this gets eventually reversed, so we concatenate them in reverse order
    {nil, [right, left]}
  end

  # If the ast fragment is unknown, return it and the accumulator;
  # it will eventually be built up into one of the above cases.
  defp parse_iolist(ast, accum),
    do: {ast, accum}

  defp to_safe_options(metric_type, options_ast) when metric_type in @safe_metric_types,
    do: options_ast

  defp to_safe_options(_metric_type, options_ast) do
    quote do
      Keyword.merge([sample_rate: 0.1], unquote(options_ast))
    end
  end
end
