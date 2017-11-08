defmodule Instruments.Probe.Value do
  @moduledoc false
  defstruct value: nil, sample_rate: nil, tags: []

  def new(value, opts) do
    tags = Keyword.get(opts, :tags)
    sample_rate = Keyword.get(opts, :sample_rate)

    %__MODULE__{value: value, tags: tags, sample_rate: sample_rate}
  end
end
