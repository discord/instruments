defmodule Instruments.Statix do
  @moduledoc """
  The default stats reporter. Uses the `Statix` library.
  """
  use Statix, runtime_config: true
end
