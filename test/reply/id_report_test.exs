defmodule ReplyIdReportTest do
  use ExUnit.Case

  alias Jeff.Reply.IdReport

  test "decode an IdReport" do
    actual = IdReport.decode(<<92, 38, 35, 25, 2, 0, 0, 2, 105, 2, 3, 4>>)

    expected = %IdReport{
      vendor: "5C2623",
      model: 25,
      version: 2,
      serial: "00000269",
      firmware: "2.3.4"
    }

    assert actual == expected
  end
end
