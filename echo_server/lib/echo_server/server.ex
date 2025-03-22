defmodule EchoServer.Server do
  alias EchoServer.Message
  alias EchoServer.Message.Body
  alias EchoServer.Node
  use GenServer
  require Logger

  # TODO use a byte buffer to handle incomplete messages.
  @all_keys [:node_state]
  @enforce_keys @all_keys
  defstruct @all_keys
  @type t :: %__MODULE__{node_state: Node.t()}

  # Public API exposed to the client
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  # Internal API for server callbacks
  @impl true
  def init(_) do
    IO.puts(:stderr, "Starting up EchoServer")

    send(self(), :read_stdin)

    {:ok, %__MODULE__{node_state: Node.new()}}
  end

  @impl true
  def handle_info(:read_stdin, %__MODULE__{} = state) do
    # TODO consider using cast to handle the input asynchronously.
    state = handle_input(state, IO.gets(:stdio, ""))

    # Keep reading stdin forever.
    send(self(), :read_stdin)

    {:noreply, state}
  end

  @spec handle_input(t(), binary()) :: t()
  def handle_input(state, input) do
    message = Message.decode(input)
    IO.inspect(:stderr, message, label: "received message")

    case message.body do
      %Body.Init{} ->
        node_id = message.body.node_id
        node_ids = message.body.node_ids

        # TODO reply with InitOk

        # Store the node_id and node_ids into our Node state.
        %__MODULE__{
          state
          | node_state:
              update_in(state.node_state, fn st ->
                put_in(st.node_id, node_id) |> put_in(st.node_ids, node_ids)
              end)
        }
    end
  end
end
