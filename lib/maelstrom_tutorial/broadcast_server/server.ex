defmodule MaelstromTutorial.BroadcastServer.Server do
  alias MaelstromTutorial.Message
  alias MaelstromTutorial.Message.Body
  alias MaelstromTutorial.BroadcastServer.Node
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

  @impl true
  def init(_) do
    log("Starting up MaelstromTutorial BroadcastServer")
    {:ok, %__MODULE__{node_state: Node.new()}}
  end

  @impl true
  def handle_cast({:read_stdin, input}, %__MODULE__{} = state) do
    # log("READING FROM STDIN: #{input}")
    # TODO consider using cast to handle the input asynchronously.
    state = handle_input(state, input)
    # log("DONE HANDLING INPUT, NEW STATE: #{inspect(state)}")

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:broadcast_ok_awaiting, {target, msg_id_awaiting, message}} = broadcast_awaiting_ok_msg,
        %__MODULE__{} = state
      ) do
    state =
      case state.node_state.unacked |> MapSet.member?({target, msg_id_awaiting}) do
        # We've already received a reply, no need to retry.
        nil ->
          # log(
          #   "No need to retry broadcast to target #{target} with original msg id #{msg_id_awaiting}."
          # )

          state

        # Retry sending the original broadcast message.
        _ ->
          # TODO BUG HERE
          # log("Relaying broadcast: #{inspect(message)}")

          # TODO I doubt this will work {:cast, msg}. If it doesn't just use a handle_info to convert to a cast.
          # Process.send_after(self(), {:cast, broadcast_awaiting_ok_msg}, @retry_timeout_ms)
          # send_message(state, message)
          state
      end

    {:noreply, state}
  end

  @spec handle_input(t(), binary()) :: t()
  def handle_input(state, input) do
    # log("RAW INPUT: #{input}")
    message = Message.decode(input)
    # log("DECODED INPUT: #{inspect(message)}")

    case message.body do
      %Body.Init{} ->
        node_id = message.body.node_id
        node_ids = message.body.node_ids

        reply = %Message{
          src: message.dest,
          dest: message.src,
          body: Body.InitOk.new(message.body.msg_id)
        }

        state = send_message(state, reply)

        # Store the node_id and node_ids into our Node state.
        state = put_in(state.node_state.node_id, node_id)
        put_in(state.node_state.node_ids, node_ids)

      # Reply with topology_ok and then set our neighbors based on the given topology.
      %Body.Topology{topology: topology} ->
        reply = %Message{
          src: message.dest,
          dest: message.src,
          body: Body.TopologyOk.new(message.body.msg_id)
        }

        send_message(state, reply)

        # TODO this atom conversion is a hack caused by the other hack in parsing where I use atoms.
        my_neighbors = Map.get(topology, String.to_existing_atom(state.node_state.node_id), [])
        put_in(state.node_state.my_neighbors, my_neighbors)

      # Record this new number, reply broadcast_ok, then relay the broadcast to each neighbor except the sender, and kick off an internal :broadcast_ok_awaiting message to handle replies to each relayed broadcast.
      %Body.Broadcast{} ->
        # log(
        #   "STATE BEFORE: #{inspect(state)}\nmessages: #{inspect(state.node_state.messages)}\nnum: #{message.body.message}"
        # )

        state = update_in(state.node_state.messages, &(&1 ++ [message.body.message]))
        # log("STATE AFTER: #{inspect(state)}")

        # Reply with a broadcast_ok.
        reply = %Message{
          src: message.dest,
          dest: message.src,
          body: Body.BroadcastOk.new(message.body.msg_id)
        }

        state = send_message(state, reply)

        state.node_state.my_neighbors
        |> Enum.reject(fn neighbor ->
          neighbor == message.src || neighbor == state.node_state.node_id
        end)
        |> Enum.reduce(state, fn neighbor, updated_state ->
          # Send out the same Broadcast message we got, but swap out the src and dest.
          broadcast = %Message{
            message
            | src: state.node_state.node_id,
              dest: neighbor
          }

          # Make sure we expect a reply and retry the same message if we don't. We do this by "registering" the message in a set that we'll be checking in the :broadcast_ok_awaiting handler.
          GenServer.cast(
            self(),
            {:broadcast_ok_awaiting, {neighbor, message.body.msg_id, message}}
          )

          put_in(state.node_state.unacked, &MapSet.put(&1, {neighbor, message.body.msg_id}))

          # The updated_state is accumulated (the msg_id counter is incremented) as we iterate until we return the final state.
          send_message(updated_state, broadcast)
        end)

      %Body.BroadcastOk{} ->
        # Update the state such that we stop infinitely :broadcast_ok_awaiting looping.
        update_in(state.node_state.unacked, fn unacked ->
          unacked |> MapSet.delete({message.src, message.body.in_reply_to})
        end)

      # Reply with read_ok and the list of messages we know about.
      %Body.Read{} ->
        reply = %Message{
          src: message.dest,
          dest: message.src,
          body: Body.ReadOk.new(state.node_state.messages, message.body.msg_id)
        }

        send_message(state, reply)
    end
  end

  @spec send_message(t(), Message.t()) :: :ok
  def send_message(state, message) do
    message = put_in(message.body.msg_id, state.node_state.current_msg_id)

    data = Message.encode(message)
    # log("SENDING REPLY: #{data}")
    :ok = IO.puts(:stdio, data)
    update_in(state.node_state.current_msg_id, &(&1 + 1))
  end

  @spec log(binary()) :: :ok
  def log(data) do
    IO.puts(:stderr, data)
  end
end
