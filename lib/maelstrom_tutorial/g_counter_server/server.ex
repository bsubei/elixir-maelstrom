defmodule MaelstromTutorial.GCounterServer.Server do
  alias MaelstromTutorial.GCounterServer.{Message, Node}
  use GenServer

  # TODO use a byte buffer to handle incomplete messages.
  @all_keys [:node_state]
  @enforce_keys @all_keys
  defstruct @all_keys
  @type t :: %__MODULE__{node_state: Node.t()}

  @periodic_ms 200

  def main(_args) do
    # children = [
    #   MaelstromTutorial.GCounterServer.Server
    #   # Supervisor.child_spec(MaelstromTutorial.GCounterServer.Server, restart: :temporary)
    # ]

    # opts = [strategy: :one_for_one, name: MaelstromTutorial.GCounterServer.Supervisor]
    # Supervisor.start_link(children, opts)

    {:ok, pid} = __MODULE__.start_link([])
    read_stdin_forever(pid)
  end

  @spec read_stdin_forever(GenServer.server()) :: :ok
  def read_stdin_forever(pid) do
    Enum.each(IO.stream(), fn data ->
      GenServer.cast(pid, {:read_stdin, data})
    end)
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl GenServer
  @spec init(any()) :: {:ok, t()}
  def init(_) do
    log("Starting up MaelstromTutorial GCounterServer")
    {:ok, %__MODULE__{node_state: Node.new()}}
  end

  @impl GenServer
  def handle_info(:replicate, %__MODULE__{} = state) do
    # Keep running this on a timer forever.
    Process.send_after(self(), :replicate, @periodic_ms)

    # Send our current counters to all of our neighbors using an internal "replicate" message.
    state =
      state.node_state.node_ids
      |> Enum.reject(&(&1 == state.node_state.node_id))
      |> Enum.reduce(state, fn neighbor, updated_state ->
        message = %Message{
          src: state.node_state.node_id,
          dest: neighbor,
          body: Message.Body.Replicate.new(state.node_state.counters)
        }

        send_message(updated_state, message)
      end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:read_stdin, input}, %__MODULE__{} = state) do
    state = handle_input(state, input)
    {:noreply, state}
  end

  @spec handle_input(t(), binary()) :: t()
  def handle_input(state, input) do
    message = Message.decode(input)

    case message.body do
      # Store the node_id and node_ids into our Node state and reply init_ok. Also start up the periodic "replicate" broadcast.
      %Message.Body.Init{} ->
        Process.send_after(self(), :replicate, @periodic_ms)

        node_id = message.body.node_id
        node_ids = message.body.node_ids

        reply = %Message{
          src: message.dest,
          dest: message.src,
          body: Message.Body.InitOk.new(message.body.msg_id)
        }

        state = send_message(state, reply)
        state = put_in(state.node_state.node_id, node_id)
        put_in(state.node_state.node_ids, node_ids)

      # Increment our counter and reply add_ok.
      %Message.Body.Add{} ->
        original_count = Map.get(state.node_state.counters, state.node_state.node_id, 0)

        state =
          update_in(
            state.node_state.counters,
            &Map.put(&1, state.node_state.node_id, original_count + message.body.delta)
          )

        reply = %Message{
          src: message.dest,
          dest: message.src,
          body: Message.Body.AddOk.new(message.body.msg_id)
        }

        send_message(state, reply)

      # Merge our counters and the one in the Replicate message. No replies.
      %Message.Body.Replicate{} ->
        # TODO because I serialize using structs, maps end up having keyword/atom keys, so I have to convert them back to strings.
        their_counters = message.body.counters |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

        update_in(
          state.node_state.counters,
          &Map.merge(&1, their_counters, fn _k, v1, v2 -> max(v1, v2) end)
        )

      # Reply with read_ok and the current count (which is the sum of all the counters).
      %Message.Body.Read{} ->
        sum = state.node_state.counters |> Map.values() |> Enum.sum()

        reply = %Message{
          src: message.dest,
          dest: message.src,
          body: Message.Body.ReadOk.new(sum, message.body.msg_id)
        }

        send_message(state, reply)
    end
  end

  @spec insert_message_id(t(), Message.t()) :: Message.t()
  def insert_message_id(state, message),
    do: put_in(message.body.msg_id, state.node_state.current_msg_id)

  @spec send_message(t(), Message.t()) :: t()
  def send_message(state, message) do
    message = insert_message_id(state, message)

    data = Message.encode(message)
    :ok = IO.puts(:stdio, data)
    update_in(state.node_state.current_msg_id, &(&1 + 1))
  end

  @spec send_message_without_id_update(Message.t()) :: :ok
  def send_message_without_id_update(message) do
    data = Message.encode(message)
    IO.puts(:stdio, data)
  end

  @spec log(binary()) :: :ok
  def log(data) do
    IO.puts(:stderr, data)
  end

  @spec stderr_inspect(any(), keyword()) :: any()
  def stderr_inspect(data, opts) do
    IO.inspect(:stderr, data, opts)
  end
end
