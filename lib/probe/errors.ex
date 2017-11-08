defmodule Instruments.Probe.Errors do
  @moduledoc false

  defmodule ProbeNameTakenError do
    defexception taken_names: []

    def message(%{taken_names: names}) do
      formatted_names = Enum.map_join(names, ", ", fn name -> "\"#{name}\"" end)
      "You're re-registering the following probes: #{formatted_names}"
    end
  end
end
