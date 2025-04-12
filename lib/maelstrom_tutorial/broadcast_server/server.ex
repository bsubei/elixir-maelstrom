defmodule MaelstromTutorial.BroadcastServer.Server do
  alias MaelstromTutorial.BroadcastServer.{Message, Node}
  use GenServer

  # TODO use a byte buffer to handle incomplete messages.
  @all_keys [:node_state]
  @enforce_keys @all_keys
  defstruct @all_keys
  @type t :: %__MODULE__{node_state: Node.t()}

  @retry_timeout_ms 200

  def main(_args) do
    # children = [
    #   MaelstromTutorial.BroadcastServer.Server
    #   # Supervisor.child_spec(MaelstromTutorial.BroadcastServer.Server, restart: :temporary)
    # ]

    # opts = [strategy: :one_for_one, name: MaelstromTutorial.BroadcastServer.Supervisor]
    # Supervisor.start_link(children, opts)

    {:ok, pid} = __MODULE__.start_link([])
    read_stdin_forever(pid)
  end

  @spec read_stdin_forever(GenServer.server()) :: :ok
  def read_stdin_forever(pid) do
    Enum.each(IO.stream(), fn data ->
      GenServer.cast(pid, {:read_stdin, data})
      # log("STREAMING DATA: #{data}")
    end)
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl GenServer
  @spec init(any()) :: {:ok, t()}
  def init(_) do
    log("Starting up MaelstromTutorial BroadcastServer")
    {:ok, %__MODULE__{node_state: Node.new()}}
  end

  @impl GenServer
  def handle_info({:broadcast_ok_awaiting, _} = broadcast_ok_awaiting_msg, state) do
    # This handle_info is only necessary because I don't know how to send a :cast using Process.send_after.
    GenServer.cast(self(), broadcast_ok_awaiting_msg)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:read_stdin, input}, %__MODULE__{} = state) do
    state = handle_input(state, input)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(
        {:broadcast_ok_awaiting, {target, message}} = broadcast_ok_awaiting_msg,
        %__MODULE__{} = state
      ) do
    msg_id_awaiting = message.body.msg_id

    state =
      case state.node_state.unacked |> MapSet.member?({target, msg_id_awaiting}) do
        # We've already received a reply, no need to retry.
        false ->
          log(
            "No need to retry broadcast to target #{target} with original msg id #{msg_id_awaiting}."
          )

          state

        # Retry sending the original broadcast message.
        _ ->
          log(
            "Retrying broadcast: #{inspect(message)} for msg awaiting: #{msg_id_awaiting} and target: #{target}"
          )

          Process.send_after(self(), broadcast_ok_awaiting_msg, @retry_timeout_ms)

          # NOTE: make sure our retried Broadcast message uses the same msg id as the original, because that's the msg id registered in the unacked.
          :ok = send_message_without_id_update(message)
          state
      end

    {:noreply, state}
  end

  @spec handle_input(t(), binary()) :: t()
  def handle_input(state, input) do
    message = Message.decode(input)

    case message.body do
      %Message.Body.Init{} ->
        node_id = message.body.node_id
        node_ids = message.body.node_ids

        reply = %Message{
          src: message.dest,
          dest: message.src,
          body: Message.Body.InitOk.new(message.body.msg_id)
        }

        state = send_message(state, reply)

        # Store the node_id and node_ids into our Node state.
        state = put_in(state.node_state.node_id, node_id)
        put_in(state.node_state.node_ids, node_ids)

      # Reply with topology_ok and then set our neighbors based on the given topology.
      %Message.Body.Topology{topology: topology} ->
        reply = %Message{
          src: message.dest,
          dest: message.src,
          body: Message.Body.TopologyOk.new(message.body.msg_id)
        }

        state = send_message(state, reply)

        # TODO this atom conversion is a hack caused by the other hack in parsing where I use atoms.
        my_neighbors = Map.get(topology, String.to_existing_atom(state.node_state.node_id), [])
        put_in(state.node_state.my_neighbors, my_neighbors)

      # Reply broadcast_ok. If we haven't already seen this, record the new message then relay the broadcast to each neighbor except the sender, and kick off an internal :broadcast_ok_awaiting message to handle replies to each relayed broadcast.
      %Message.Body.Broadcast{} ->
        # Reply with a broadcast_ok always.
        reply = %Message{
          src: message.dest,
          dest: message.src,
          body: Message.Body.BroadcastOk.new(message.body.msg_id)
        }

        state = send_message(state, reply)

        if Enum.member?(state.node_state.messages, message.body.message) do
          # Do nothing else if we've already seen this message.
          state
        else
          state = update_in(state.node_state.messages, &(&1 ++ [message.body.message]))

          state.node_state.my_neighbors
          |> Enum.reject(fn neighbor ->
            neighbor == message.src || neighbor == state.node_state.node_id
          end)
          |> Enum.reduce(state, fn neighbor, updated_state ->
            # Send out the same Broadcast message we got, but swap out the src and dest, and the updated message id.
            broadcast = %Message{
              insert_message_id(updated_state, message)
              | src: state.node_state.node_id,
                dest: neighbor
            }

            # Make sure we expect a reply and retry the same Broadcast message if we don't. We do this by "registering" the message in a set that we'll be checking in the :broadcast_ok_awaiting handler.
            updated_state =
              update_in(
                updated_state.node_state.unacked,
                # Here, we store a tuple of: 1) the node id we're awaiting a BroadcastOk from, and 2) the current message id we're using for the broadcast, which we'll look for in in_reply_to in the broadcast_ok reply.
                &MapSet.put(&1, {neighbor, state.node_state.current_msg_id})
              )

            Process.send_after(
              self(),
              {:broadcast_ok_awaiting, {neighbor, broadcast}},
              @retry_timeout_ms
            )

            # The updated_state is accumulated (the msg_id counter is incremented) as we iterate until we return the final state.
            log(
              "Relaying broadcast to #{neighbor} the message #{broadcast.body.message} with msg id #{updated_state.node_state.current_msg_id}"
            )

            send_message(updated_state, broadcast)
          end)
        end

      %Message.Body.BroadcastOk{} ->
        # Update the state so that we stop infinitely :broadcast_ok_awaiting looping.
        # TODO consider storing the reverse: "acked". So we don't try to broadcast again the same message. Might have to switch to using the "message" itself instead of msg id. But that might be better overall since it's clearly bug prone.
        update_in(
          state.node_state.unacked,
          &MapSet.delete(&1, {message.src, message.body.in_reply_to})
        )

      # Reply with read_ok and the list of messages we know about.
      %Message.Body.Read{} ->
        reply = %Message{
          src: message.dest,
          dest: message.src,
          body: Message.Body.ReadOk.new(state.node_state.messages, message.body.msg_id)
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
    # log("SENDING REPLY: #{data}")
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
