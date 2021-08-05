defmodule ReplyCapabilityTest do
  use ExUnit.Case
  alias Jeff.Reply.Capability

  test "decode capabilities" do
    data =
      [
        <<3, 1, 1>>,
        <<4, 4, 1>>,
        <<5, 2, 1>>,
        <<8, 1, 1>>,
        <<9, 1, 1>>,
        <<10, 194, 1>>
      ]
      |> :erlang.list_to_binary()

    actual = Capability.decode(data)

    expected =
      [
        {3, 1, 1, "Card Data Format"},
        {4, 4, 1, "Reader LED Control"},
        {5, 2, 1, "Reader Audible Output"},
        {8, 1, 1, "Check Character Support"},
        {9, 1, 1, "Communication Security"},
        {10, 194, 1, "Receive BufferSize"}
      ]
      |> Enum.map(&build_capability/1)

    assert actual == expected
  end

  defp build_capability({function, compliance, number_of, description}) do
    %Capability{
      function: function,
      compliance: compliance,
      number_of: number_of,
      description: description
    }
  end
end
