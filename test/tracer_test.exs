defmodule Jeff.TracerTest do
  use ExUnit.Case, async: true

  alias Jeff.Tracer

  setup_all do
    # Default state
    {:ok, state} = Tracer.init([])
    %{state: state}
  end

  test "default state", %{state: state} do
    assert %{
             ignore_polls: true,
             ignore_partials: false,
             ignore_marks: true,
             partials_limit: 100,
             partials: []
           } = state
  end

  test "configuration change", %{state: state} do
    new = [
      ignore_polls: !state.ignore_polls,
      ignore_partials: !state.ignore_partials,
      ignore_marks: !state.ignore_marks,
      partials_limit: state.partials_limit + 100
    ]

    {:reply, :ok, updated} = Tracer.handle_call({:configure, new}, self(), state)
    assert updated.ignore_polls == !state.ignore_polls
    assert updated.ignore_partials == !state.ignore_partials
    assert updated.ignore_marks == !state.ignore_marks
    assert updated.partials_limit == state.partials_limit + 100
  end

  test "can ignore partials when set", %{state: state} do
    state = %{state | ignore_partials: true}

    assert {:noreply, ^state} = Tracer.handle_cast({:log, :partial, <<123>>}, state)
  end

  test "can ignore marks when set", %{state: state} do
    state = %{state | ignore_marks: true, ignore_partials: false}

    assert {:noreply, ^state} = Tracer.handle_cast({:log, :partial, <<0xFF>>}, state)
    assert {:noreply, ^state} = Tracer.handle_cast({:log, :partial, <<0xFF, 0xFF, 0xFF>>}, state)
    assert {:noreply, ^state} = Tracer.handle_cast({:log, :partial, [<<0xFF>>]}, state)

    assert {:noreply, ^state} =
             Tracer.handle_cast({:log, :partial, [<<0xFF>>, 0xFF, [0xFF]]}, state)
  end

  test "can accumulate marks", %{state: state} do
    state = %{state | ignore_marks: false, ignore_partials: false, partials: [<<123>>]}

    assert {:noreply, %{partials: [<<0xFF>>, <<123>>]}} =
             Tracer.handle_cast({:log, :partial, <<0xFF>>}, state)
  end

  test "logs partials and resets buffer when limit is reached", %{state: state} do
    state = %{
      state
      | ignore_marks: true,
        ignore_partials: false,
        partials_limit: 1,
        partials: [<<123>>]
    }

    {result, log} =
      ExUnit.CaptureLog.with_log(fn -> Tracer.handle_cast({:log, :partial, <<253>>}, state) end)

    assert {:noreply, %{partials: []}} = result
    assert log =~ "[Jeff <-- RX]\e[33m partial: \e[36m<<123, 253>>"
  end

  test "accumulates partials", %{state: state} do
    state = %{state | ignore_marks: true, ignore_partials: false, partials: [<<123>>]}

    assert {:noreply, %{partials: [<<253>>, <<123>>]}} =
             Tracer.handle_cast({:log, :partial, <<253>>}, state)
  end

  test "can ignore polls and acks", %{state: state} do
    ack = <<83, 129, 8, 0, 6, 64, 106, 96>>
    poll1 = <<255, 83, 1, 8, 0, 7, 96, 233, 85>>
    poll2 = <<83, 1, 8, 0, 7, 96, 233, 85>>

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        Tracer.handle_cast({:log, :rx, ack}, state)
        Tracer.handle_cast({:log, :tx, poll1}, state)
        Tracer.handle_cast({:log, :tx, poll2}, state)
      end)

    assert log == ""
  end

  test "can log polls and acks", %{state: state} do
    state = %{state | ignore_polls: false}

    ack = <<83, 129, 8, 0, 6, 64, 106, 96>>
    poll1 = <<255, 83, 1, 8, 0, 7, 96, 233, 85>>
    poll2 = <<83, 1, 8, 0, 7, 96, 233, 85>>

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        Tracer.handle_cast({:log, :rx, ack}, state)
        Tracer.handle_cast({:log, :tx, poll1}, state)
        Tracer.handle_cast({:log, :tx, poll2}, state)
      end)

    assert log =~ "[Jeff \e[37m<-- RX\e[36m] #{inspect(ack)}"
    assert log =~ "[Jeff \e[32m--> TX\e[36m] #{inspect(poll1)}"
    assert log =~ "[Jeff \e[32m--> TX\e[36m] #{inspect(poll2)}"
  end

  test "logs partials when valid packet is logged", %{state: state} do
    state = %{
      state
      | ignore_marks: true,
        ignore_partials: false,
        partials_limit: 1,
        partials: [<<252>>]
    }

    {result, log} =
      ExUnit.CaptureLog.with_log(fn -> Tracer.handle_cast({:log, :tx, <<253>>}, state) end)

    assert {:noreply, %{partials: []}} = result
    assert log =~ "[Jeff <-- RX]\e[33m partial: \e[36m<<252>>"
    assert log =~ "[Jeff \e[32m--> TX\e[36m] <<253>>"
  end
end
