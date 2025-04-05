defmodule MaelstromTutorial.EchoServer.Server do
  alias MaelstromTutorial.EchoServer.{Message, Node}
  use GenServer

  # TODO use a byte buffer to handle incomplete messages.
  @all_keys [:node_state]
  @enforce_keys @all_keys
  defstruct @all_keys
  @type t :: %__MODULE__{node_state: Node.t()}

  def main(_args) do
    # children = [
    #   MaelstromTutorial.EchoServer.Server
    #   # Supervisor.child_spec(MaelstromTutorial.EchoServer.Server, restart: :temporary)
    # ]

    # opts = [strategy: :one_for_one, name: MaelstromTutorial.EchoServer.Supervisor]
    # Supervisor.start_link(children, opts)

    {:ok, pid} = __MODULE__.start_link([])
    read_stdin_forever(pid)
  end

  def read_stdin_forever(pid) do
    Enum.each(IO.stream(), fn data ->
      GenServer.cast(pid, {:read_stdin, data})
      log("STREAMING DATA: #{data}")
    end)
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl true
  def init(_) do
    log("Starting up MaelstromTutorial EchoServer")
    {:ok, %__MODULE__{node_state: Node.new()}}
  end

  @impl true
  def handle_cast({:read_stdin, input}, %__MODULE__{} = state) do
    log("READING FROM STDIN: #{input}")
    # TODO consider using cast to handle the input asynchronously.
    state = handle_input(state, input)
    log("DONE HANDLING INPUT, NEW STATE: #{inspect(state)}")

    {:noreply, state}
  end

  # @spec read_message() :: Message.t()
  # def read_message() do
  #   log("BEFORE STDIN")
  #   data = IO.read(:stdio, :line)
  #   log("Read from STDIN: #{data}")
  #   Message.decode(data)
  # end

  @spec send_message(t(), Message.t()) :: t()
  def send_message(state, message) do
    message = put_in(message.body.msg_id, state.node_state.current_msg_id)

    data = Message.encode(message)
    log("SENDING REPLY: #{data}")
    :ok = IO.puts(:stdio, data)
    update_in(state.node_state.current_msg_id, &(&1 + 1))
  end

  @spec log(binary()) :: :ok
  def log(data) do
    IO.puts(:stderr, data)
  end

  @spec handle_input(t(), binary()) :: t()
  def handle_input(state, input) do
    log("RAW INPUT: #{input}")
    message = Message.decode(input)
    log("DECODED INPUT: #{inspect(message)}")

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

      %Message.Body.Echo{echo: echo} ->
        reply = %Message{
          src: message.dest,
          dest: message.src,
          body: Message.Body.EchoOk.new(echo, message.body.msg_id)
        }

        send_message(state, reply)
    end
  end
end
