defmodule Jeff.FileTransferTest do
  use ExUnit.Case, async: true

  alias Jeff.{Command.FileTransfer, Reply.FileTransferStatus}

  describe "command_set/2" do
    test "data < 128 bytes" do
      assert FileTransfer.command_set(<<1, 2>>) == [
               %FileTransfer{data: <<1, 2>>, fragment_size: 2, offset: 0, total_size: 2}
             ]
    end

    test "data > 128 bytes defaults first command size" do
      ones = :binary.copy(<<1>>, 128)
      twos = :binary.copy(<<2>>, 15)
      [first, second] = FileTransfer.command_set(ones <> twos)
      assert %FileTransfer{data: ^ones, fragment_size: 128, total_size: 143} = first
      assert %FileTransfer{data: ^twos, fragment_size: 15, total_size: 143} = second
    end

    test "custom max message length" do
      [first, second] = FileTransfer.command_set(<<1, 2, 3, 4, 5, 6>>, 3)
      assert %FileTransfer{data: <<1, 2, 3>>, fragment_size: 3, total_size: 6} = first
      assert %FileTransfer{data: <<4, 5, 6>>, fragment_size: 3, total_size: 6} = second
    end

    test "increments offsets" do
      [first, second, third] = FileTransfer.command_set(:binary.copy(<<1>>, 1024), 512)
      assert %FileTransfer{fragment_size: 128, offset: 0} = first
      assert %FileTransfer{fragment_size: 512, offset: 128} = second
      assert %FileTransfer{fragment_size: 384, offset: 640} = third
    end
  end

  describe "adjust_from_reply/2" do
    test "halts when NAK errors" do
      err = %Jeff.Reply.ErrorCode{code: 2}
      assert {:halt, ^err} = FileTransfer.adjust_from_reply(%Jeff.Reply{name: NAK, data: err}, [])
    end

    test "halts when no more commands" do
      ftstat = %FileTransferStatus{status: :ok}

      assert {:halt, ^ftstat} =
               FileTransfer.adjust_from_reply(%Jeff.Reply{name: FTSTAT, data: ftstat}, [])
    end

    test "adds idle message when finishing status" do
      ftstat = %FileTransferStatus{status: :finishing}
      cmd = %FileTransfer{total_size: 10, fragment_size: 3, offset: 7}

      assert {:cont, [idle, ^cmd], _} =
               FileTransfer.adjust_from_reply(%Jeff.Reply{name: FTSTAT, data: ftstat}, [cmd])

      assert idle.offset == idle.total_size
      assert idle.fragment_size == 0
    end

    test "adds idle message and updates max length when finishing status" do
      ftstat = %FileTransferStatus{status: :finishing, update_msg_max: 1}
      cmd = %FileTransfer{total_size: 10, fragment_size: 2, offset: 8, data: <<1, 2>>}

      assert {:cont, [idle, one, two], _} =
               FileTransfer.adjust_from_reply(%Jeff.Reply{name: FTSTAT, data: ftstat}, [cmd])

      assert idle.offset == idle.total_size
      assert idle.fragment_size == 0

      assert %{total_size: 10, fragment_size: 1, offset: 8, data: <<1>>} = one
      assert %{total_size: 10, fragment_size: 1, offset: 9, data: <<2>>} = two
    end

    test "continues with updated max length for successful statuses" do
      ftstat = %FileTransferStatus{status: :ok, update_msg_max: 1}
      ftstat2 = %FileTransferStatus{status: :processed, update_msg_max: 1}
      ftstat3 = %FileTransferStatus{status: :rebooting, update_msg_max: 1}

      commands = [%FileTransfer{total_size: 10, fragment_size: 2, offset: 8, data: <<1, 2>>}]

      expected = [
        %FileTransfer{total_size: 10, fragment_size: 1, offset: 8, data: <<1>>},
        %FileTransfer{total_size: 10, fragment_size: 1, offset: 9, data: <<2>>}
      ]

      assert {:cont, ^expected, _} =
               FileTransfer.adjust_from_reply(%Jeff.Reply{name: FTSTAT, data: ftstat}, commands)

      assert {:cont, ^expected, _} =
               FileTransfer.adjust_from_reply(%Jeff.Reply{name: FTSTAT, data: ftstat2}, commands)

      assert {:cont, ^expected, _} =
               FileTransfer.adjust_from_reply(%Jeff.Reply{name: FTSTAT, data: ftstat3}, commands)
    end

    test "continues with successful statuses" do
      ftstat = %FileTransferStatus{status: :ok, update_msg_max: 0}
      ftstat2 = %FileTransferStatus{status: :processed, update_msg_max: 0}
      ftstat3 = %FileTransferStatus{status: :rebooting, update_msg_max: 0}

      commands = [
        %FileTransfer{total_size: 10, offset: 5, fragment_size: 5, data: <<1, 2, 3, 4, 5>>}
      ]

      assert {:cont, ^commands, _} =
               FileTransfer.adjust_from_reply(%Jeff.Reply{name: FTSTAT, data: ftstat}, commands)

      assert {:cont, ^commands, _} =
               FileTransfer.adjust_from_reply(%Jeff.Reply{name: FTSTAT, data: ftstat2}, commands)

      assert {:cont, ^commands, _} =
               FileTransfer.adjust_from_reply(%Jeff.Reply{name: FTSTAT, data: ftstat3}, commands)
    end

    test "halts with unsuccessful FTSTAT" do
      bad = [:abort, :unrecognized_contents, :malformed, -5, -100]

      commands = [
        %FileTransfer{total_size: 10, offset: 5, fragment_size: 5, data: <<1, 2, 3, 4, 5>>}
      ]

      for status <- bad do
        ftstat = %FileTransferStatus{status: status}

        assert {:halt, ^ftstat} =
                 FileTransfer.adjust_from_reply(%Jeff.Reply{name: FTSTAT, data: ftstat}, commands)
      end
    end
  end
end
