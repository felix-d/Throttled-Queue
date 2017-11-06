require IEx
defmodule ThrottledQueue do
  @moduledoc """
  This throttled queue performs actions asynchronously and keep the client
  informed of the status of the enqueued item through its lifecycle.

  ## Messages

  The queue process will send status updates
  to the client.

    - `{:dequeued, ref}`: The action has been dequeued and is about to be executed. `ref` is the message reference returned by `ThrottledQueue.enqueue`.
    - `{:position, ref, position}`: The new position in the queue with the message reference.
    - `{:result, ref, result}`: The result of the action with the message reference.
    - `{:error, ref}`: An error occured while executing the action.

  ## Examples

      iex> {:ok, _pid} = ThrottledQueue.start_link(wait: 1000)
      iex> {:ok, _ref, 0} = ThrottledQueue.enqueue(fn ->
      ...> Process.sleep(3000)
      ...> :foo
      ...> end)
      iex> {:ok, _ref, 1} = ThrottledQueue.enqueue(fn -> :bar end)
      iex> {:ok, _ref, 2} = ThrottledQueue.enqueue(fn -> :yeee end)
      iex> {:ok, ref, 3} = ThrottledQueue.enqueue(fn -> :yeee end)
      iex> is_reference(ref)
      true

  ### Receiving messages

      receive do
        {:position, ref, pos} -> do_something_with_position_in_line(ref, pos)
        {:dequeued, ref} -> do_something_when_dequeued(ref)
        {:result, ref, result} -> do_something_with_the_result(ref, result)
        {:error, ref} -> do_something_with_the_error(ref)
      end

  """

  use GenServer

  @name __MODULE__
  @default_wait 500
  @default_max_queue 10_000

  defmodule Item do
    @moduledoc false
    defstruct [:action, :ref, :from]
  end

  @doc """
  Starts the queue process.

  ## Parameters

    - `name`: Atom. Identifier for the queue. Defaults to **ThrottledQueue** (optional).
    - `wait`: Integer. The wait time between actions in milliseconds. Defaults to 500.
    - `max_queue`: Integer. The maximum number of items in the queue. Defaults to 10_000

  ## Examples

      iex> {:ok, pid} = ThrottledQueue.start_link(
      ...> name: :my_queue,
      ...> max_queue: 100,
      ...> wait: 5000
      ...> )
      iex> is_pid(pid)
      true

  """
  def start_link(opts \\ []) do
    opts = [
      max_queue: @default_max_queue,
      wait: @default_wait,
      name: @name,
    ] |> Keyword.merge(opts)

    GenServer.start_link(@name, %{
      last_dequeued: nil,
      queue: [],
      pending: %{},
      wait: Keyword.get(opts, :wait),
      max_queue: Keyword.get(opts, :max_queue),
    }, name: Keyword.get(opts, :name))
  end

  @doc """
  Enqueues an action in the queue.

  ## Parameters

    - `name`: Atom to identify the queue. Defaults to **#{@name}** (optional).
    - `action`: Function to enqueue.

  ## Returns

    - `{:ok, ref, position}`: Returns a tuple with `:ok`, the message reference and the position in the queue.
    - `:error`: Returns `:error` if the queue is full.

  ## Examples

      iex> ThrottledQueue.start_link(max_queue: 2)
      iex> {:ok, _ref, 0} = ThrottledQueue.enqueue(fn -> Process.sleep(3000) end)
      iex> {:ok, _ref, 1} = ThrottledQueue.enqueue(fn -> :bar end)
      iex> ThrottledQueue.enqueue(fn -> :hey end)
      :error

  """
  def enqueue(name \\ @name, action) do
    GenServer.call(name, {:enqueue, action})
  end

  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  def handle_call({:enqueue, action}, {from, ref}, %{max_queue: max_queue, queue: queue} = state) do
    len = length(queue)
    new_queue = queue ++ [%Item{action: action, ref: ref, from: from}]

    cond do
      len >= max_queue ->
        {:reply, :error, state}
      len == 0 ->
        GenServer.cast(self(), :dequeue)
        {:reply, {:ok, ref, len}, %{state | queue: new_queue}}
      true ->
        {:reply, {:ok, ref, len}, %{state | queue: new_queue}}
    end
  end

  def handle_cast(:dequeue, %{wait: wait, last_dequeued: last_dequeued} = state) do
    spent = spent_time(last_dequeued)
    cond do
      spent == nil ->
        Process.send_after(self(), :delayed_process, wait)
        {:noreply, state}
      spent > wait ->
        process(state)
      true ->
        Process.send_after(self(), :delayed_process, wait - spent)
        {:noreply, state}
    end
  end

  def handle_info(:delayed_process, state) do
    process(state)
  end

  def handle_info({:processed, %Item{from: from, ref: ref}, result}, state) do
    send(from, {:result, ref, result})
    {:noreply, state}
  end

  def handle_info({:EXIT, task_pid, :killed}, %{pending: pending} = state) do
    %Item{ref: ref, from: from} = Map.get(pending, task_pid)
    send(from, {:error, ref})
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp process(%{queue: [%Item{from: from, ref: ref} = item | tail], pending: pending} = state) do
    send(from, {:dequeued, ref})

    last_dequeued = now()

    task_pid = spawn_task(item)

    notify_position(tail)

    if length(tail) > 0 do
      GenServer.cast(self(), :dequeue)
    end

    {:noreply, %{state | pending: pending |> Map.put(task_pid, item), queue: tail, last_dequeued: last_dequeued}}
  end

  defp spawn_task(%Item{action: action} = item) do
    queue_pid = self()
    spawn_link(fn ->
      response = action.()
      send(queue_pid, {:processed, item, response})
    end)
  end

  defp spent_time(last_dequeued) do
    case last_dequeued do
      nil -> nil
      _ -> DateTime.diff(now(), last_dequeued, :millisecond)
    end
  end

  defp notify_position([]), do: nil
  defp notify_position(queue) do
    queue
    |> Enum.with_index
    |> Enum.each(fn {%Item{from: from, ref: ref, action: _action}, pos} ->
      send from, {:position, ref, pos}
    end)
  end

  defp now do
    DateTime.utc_now
  end
end
