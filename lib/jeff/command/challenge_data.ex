defmodule Jeff.Command.ChallengeData do
  @moduledoc false

  def encode(server_rnd: rnd), do: rnd
end
