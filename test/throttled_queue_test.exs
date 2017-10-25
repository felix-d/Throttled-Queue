defmodule ThrottledQueueTest do
  use ExUnit.Case
  # doctest ThrottledQueue

  test "ThrottledQueue.start_link starts the queue" do
    {:ok, pid} = ThrottledQueue.start_link
    assert is_pid(pid)
    assert :sys.get_status(ThrottledQueue)
  end

  test "ThrottledQueue.start_link can take a custom name" do
    {:ok, pid} = ThrottledQueue.start_link(name: :my_queue)
    assert is_pid(pid)
    assert :sys.get_status(:my_queue)
  end

  test "ThrottledQueue.start_link can take a custom wait time" do
    {:ok, pid} = ThrottledQueue.start_link(wait: 100)
    assert is_pid(pid)
    %{wait: 100} = state(:sys.get_status(ThrottledQueue))
  end

  test "ThrottledQueue.start_link has a default wait time" do
    {:ok, pid} = ThrottledQueue.start_link
    assert is_pid(pid)
    %{wait: 500} = state(:sys.get_status(ThrottledQueue))
  end

  test "ThrottledQueue.start_link can take a custom max_queue" do
    {:ok, pid} = ThrottledQueue.start_link(max_queue: 100)
    assert is_pid(pid)
    %{max_queue: 100} = state(:sys.get_status(ThrottledQueue))
  end

  test "ThrottledQueue.start_link has a default max_queue" do
    {:ok, pid} = ThrottledQueue.start_link
    assert is_pid(pid)
    %{max_queue: 10_000} = state(:sys.get_status(ThrottledQueue))
  end

  defp state(name) do
    {_, _, _, status} = :sys.get_status(ThrottledQueue)
    [_, _, _, _, [_, _, {:data, [{'State', state}]}]] = status
    state
  end
end
