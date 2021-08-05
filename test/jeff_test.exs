defmodule JeffTest do
  use ExUnit.Case
  doctest Jeff

  test "greets the world" do
    assert Jeff.hello() == :world
  end
end
