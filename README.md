# ThrottledQueue

[See documentation here!](https://hexdocs.pm/throttled_queue/0.1.0-dev/api-reference.html)

Simple throttled queue with live status updates.

This throttled queue performs actions asynchronously and keep the client
informed of the status of the enqueued item through its lifecycle.

## Installation

```elixir
def deps do
  [
    {:throttled_queue, "~> 0.1.0-dev"},
  ]
end
```

## Available options:

- `name`: The name of the queue. Defaults to `ThrottledQueue`.
- `max_queue`: The maximum capacity of the queue. Defaults to `10_000`.
- `wait`: The throttling time between each dequeue. Defaults to `500` milliseconds.

## Available status updates:

- `{:dequeued, ref}`: The action has been dequeued and is about to be executed. `ref` is the message reference returned by `ThrottledQueue.enqueue`.
- `{:position, ref, position}`: The new position in the queue with the message reference.
- `{:result, ref, result}`: The result of the action with the message reference.
- `{:error, ref}`: An error occured while executing the action.


