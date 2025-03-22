defmodule EchoServer.Server do
  alias EchoServer.Message
  alias EchoServer.Message.Body
  alias EchoServer.Node
  use GenServer
  require Logger

  @type t :: %__MODULE__{buffer: binary(), node_state: Node.t()}
  defstruct [:buffer, :node_state]

  # Public API exposed to the client
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  # Internal API for server callbacks
  @impl true
  def init(_) do
    send(self(), :read_stdin)
    {:ok, %__MODULE__{}}
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

    state =
      case message do
        %Body.Init{} = init ->
          # TODO do something
          IO.inspect(init)
          state

        unknown ->
          IO.inspect(unknown)
          state
      end

    state
  end
end
