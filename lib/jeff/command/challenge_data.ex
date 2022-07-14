defmodule Jeff.Command.ChallengeData do
  @moduledoc false

  @spec encode(server_rnd: binary()) :: binary()
  def encode(server_rnd: rnd), do: rnd
end
