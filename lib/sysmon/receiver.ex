defmodule Instruments.Sysmon.Receiver do

  @type info :: List.t({term(), term()})

  @callback handle_busy_port(pid(), port()) :: :ok

  @callback handle_busy_dist_port(pid(), port()) :: :ok

  @callback handle_long_gc(pid(), info()) :: :ok

  @callback handle_long_message_queue(pid(), boolean()) :: :ok

  @callback handle_long_schedule(pid(), info()) :: :ok

  @callback handle_large_heap(pid(), info()) :: :ok
end
