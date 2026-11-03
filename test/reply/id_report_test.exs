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

  test "vendor codes with leading zeroes get padded" do
    leading_zeroes = IdReport.decode(<<1, 1, 1, 48, 1, 100, 106, 61, 0, 4, 8, 1>>)
    all_zeroes = IdReport.decode(<<0, 0, 0, 48, 1, 100, 106, 61, 0, 4, 8, 1>>)
    intermittent_zeroes = IdReport.decode(<<0, 16, 1, 48, 1, 100, 106, 61, 0, 4, 8, 1>>)

    assert leading_zeroes.vendor == "010101"
    assert all_zeroes.vendor == "000000"
    assert intermittent_zeroes.vendor == "001001"
  end
end
