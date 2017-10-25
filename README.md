# ThrottledQueue

Simple throttled queue with live status updates.

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

```elixir
iex> {:ok, _pid} = ThrottledQueue.start_link(wait: 1000)
iex> {:ok, _ref, 0} = ThrottledQueue.enqueue(fn ->
...> Process.sleep(3000)
...> :foo
...> end) # Processed right away because it's the first element in the queue.
iex> {:ok, _ref, 0} = ThrottledQueue.enqueue(fn -> :bar end)
iex> {:ok, _ref, 1} = ThrottledQueue.enqueue(fn -> :yeee end)
iex> {:ok, ref, 2} = ThrottledQueue.enqueue(fn -> :yeee end)
iex> is_reference(ref)
true
```

## Receiving messages

```elixir
receive do
  {:position, ref, pos} -> do_something_with_position_in_line(ref, pos)
  {:dequeued, ref} -> do_something_when_dequeued(ref)
  {:result, ref, result} -> do_something_with_the_result(ref, result)
  {:error, ref} -> do_something_with_the_error(ref)
end
```

## API

### ThrottledQueue.start_link

Starts the queue process.

#### Parameters

- `name`: Atom. Identifier for the queue. Defaults to **ThrottledQueue** (optional).
- `wait`: Integer. The wait time between actions in milliseconds. Defaults to 500.
- `max_queue`: Integer. The maximum number of items in the queue. Defaults to 10_000

#### Examples

```elixir
iex> {:ok, pid} = ThrottledQueue.start_link(
...> name: :my_queue,
...> max_queue: 100,
...> wait: 5000
...> )
iex> is_pid(pid)
true
```

### ThrottledQueue.enqueue

Enqueues an action in the queue.

#### Parameters

- `name`: Atom to identify the queue. Defaults to **ThrottledQueue** (optional).
- `action`: Function to enqueue.

#### Returns

- `{:ok, ref, position}`: Returns a tuple with `:ok`, the message reference and the position in the queue.
- `:error`: Returns `:error` if the queue is full.

#### Examples

```elixir
iex> ThrottledQueue.start_link(max_queue: 1)
iex> {:ok, _ref, 0} = ThrottledQueue.enqueue(fn -> Process.sleep(3000) end)
iex> {:ok, _ref, 0} = ThrottledQueue.enqueue(fn -> :bar end)
iex> {:ok, _ref, 1} = ThrottledQueue.enqueue(fn -> :hey end)
iex> ThrottledQueue.enqueue(fn -> :hey end)
:error
```

## Installation

```elixir
def deps do
  [
    {:throttled_queue, git: "https://github.com/felix-d/throttled_queue.git"}
  ]
end
```
