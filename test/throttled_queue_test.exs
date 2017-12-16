defmodule ThrottledQueueTest do
  use ExUnit.Case
  doctest ThrottledQueue

  test "ThrottledQueue.start_link starts the queue" do
    {:ok, pid} = ThrottledQueue.start_link
    assert is_pid(pid)
    assert :sys.get_status(ThrottledQueue)
  end

  test "ThrottledQueue.start starts the queue" do
    {:ok, pid} = ThrottledQueue.start(name: :foo)
    assert is_pid(pid)
    assert :sys.get_status(:foo)
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

  test "ThrottledQueue.enqueue enqueues actions" do
    {:ok, _pid} = ThrottledQueue.start_link(wait: 5)

    {:ok, ref1, 0} = ThrottledQueue.enqueue(fn -> :foo end)
    {:ok, ref2, 1} = ThrottledQueue.enqueue(fn -> :bar end)
    {:ok, ref3, 2} = ThrottledQueue.enqueue(fn -> :foobar end)
    {:ok, ref4, 3} = ThrottledQueue.enqueue(fn -> :zoo end)

    assert_receive {:dequeued, ^ref1}
    assert_receive {:result, ^ref1, :foo}
    assert_receive {:position, ^ref2, 0}
    assert_receive {:dequeued, ^ref2}
    assert_receive {:result, ^ref2, :bar}
    assert_receive {:position, ^ref3, 1}
    assert_receive {:position, ^ref3, 0}
    assert_receive {:dequeued, ^ref3}
    assert_receive {:result, ^ref3, :foobar}
    assert_receive {:position, ^ref4, 2}
    assert_receive {:position, ^ref4, 1}
    assert_receive {:position, ^ref4, 0}
    assert_receive {:dequeued, ^ref4}
    assert_receive {:result, ^ref4, :zoo}
  end

  test "ThrottledQueue.enqueue returns :error is the queue is full" do
    {:ok, _pid} = ThrottledQueue.start_link(max_queue: 2)

    {:ok, _ref1, 0} = ThrottledQueue.enqueue(fn -> :foo end)
    {:ok, _ref2, 1} = ThrottledQueue.enqueue(fn -> :bar end)
    :error = ThrottledQueue.enqueue(fn -> :foobar end)
  end

  test "ThrottledQueue.clear clears the queue" do
    {:ok, _pid} = ThrottledQueue.start_link(wait: 1000)

    ThrottledQueue.enqueue(fn -> :foo end)
    ThrottledQueue.enqueue(fn -> :bar end)

    queue_state = state(:sys.get_status(ThrottledQueue))
    %{
      last_dequeued: nil,
      max_queue: 10000,
      pending: %{},
      queue: [_action1, _action2],
      wait: 1000
    } = queue_state

    ThrottledQueue.clear

    queue_state = state(:sys.get_status(ThrottledQueue))
    %{
      last_dequeued: nil,
      max_queue: 10000,
      pending: %{},
      queue: [],
      wait: 1000,
    } = queue_state
  end

  test ".remove(from: pid) removes items enqueued from pid" do
    {:ok, _pid} = ThrottledQueue.start_link(wait: 1000)

    ThrottledQueue.enqueue(fn -> :foo end)

    %Task{pid: task_pid} = task = Task.async(fn ->
      ThrottledQueue.enqueue(fn -> :bar end)
    end)

    Task.await(task)

    queue_state = state(:sys.get_status(ThrottledQueue))
    %{
      last_dequeued: nil,
      max_queue: 10000,
      pending: %{},
      queue: [_action1, _action2],
      wait: 1000
    } = queue_state

    ThrottledQueue.remove(from: self())

    queue_state = state(:sys.get_status(ThrottledQueue))
    %{
      last_dequeued: nil,
      max_queue: 10000,
      pending: %{},
      queue: [%ThrottledQueue.Item{from: ^task_pid}],
      wait: 1000
    } = queue_state
  end

  defp state(info) do
    {_, _, _, status} = info
    [_, _, _, _, [_, _, {:data, [{'State', state}]}]] = status
    state
  end
end
