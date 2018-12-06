defmodule Instruments.CustomFunctions do
  @moduledoc """
  Creates custom prefixed functions

  Often, a module will have functions that all have a common prefix.
  It's somewhat tedious to have to put this prefix in every call to
  every metric function. Using this module can help somewhat.

  When you `use` this module, it defines custom, module-specific metrics
  functions that include your prefix. For example:

  ```
  defmodule Prefixed do
    use Instruments.CustomFunctions, prefix: "my.module"

    def do_something() do
      increment("do_something_counts")
      do_another_thing()
    end

    def long_running() do
       measure("timed_fn", &compute/0)
    end

    defp compute(), do: Process.sleep(10_000)
    defp do_another_thing, do: 3
  end
  ```

  In the above example, we increment `do_something_counts` and `timed_fn`, yet
  the metrics emitted are `my.module.do_something_counts` and `my.module.timed_fn`.
  """

  defmacro __using__(opts) do
    prefix =
      case Keyword.fetch!(opts, :prefix) do
        prefix_string when is_bitstring(prefix_string) ->
          prefix_string

        ast ->
          {computed_prefix, _} = Code.eval_quoted(ast)
          computed_prefix
      end

    prefix_with_dot = "#{prefix}."

    quote do
      use Instruments

      @doc false
      def increment(key, value \\ 1, options \\ []) do
        Instruments.increment([unquote(prefix_with_dot), key], value, options)
      end

      @doc false
      def decrement(key, value \\ 1, options \\ []) do
        Instruments.decrement([unquote(prefix_with_dot), key], value, options)
      end

      @doc false
      def gauge(key, value, options \\ []) do
        Instruments.gauge([unquote(prefix_with_dot), key], value, options)
      end

      @doc false
      def histogram(key, value, options \\ []) do
        Instruments.histogram([unquote(prefix_with_dot), key], value, options)
      end

      @doc false
      def timing(key, value, options \\ []) do
        Instruments.timing([unquote(prefix_with_dot), key], value, options)
      end

      @doc false
      def set(key, value, options \\ []) do
        Instruments.set([unquote(prefix_with_dot), key], value, options)
      end

      @doc false
      def measure(key, options \\ [], func) do
        Instruments.measure([unquote(prefix_with_dot), key], options, func)
      end
    end
  end
end
