defmodule Echo.ConnectionManager do
  use GenServer
  require Logger
  alias Echo.Connection

  @type t :: %__MODULE__{listen_socket: :gen_tcp.socket()}
  defstruct [:listen_socket]

  # Public API exposed to the client
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  # Internal API for server callbacks
  @impl true
  def init(args) do
    port = Keyword.get(args, :port)

    listen_options = [
      :binary,
      # TODO consider using :once.
      active: true,
      exit_on_close: false,
      reuseaddr: true,
      backlog: 25
    ]

    # Create an "active" listening socket (i.e. bind to that port) and start attempting to accept incoming connections.
    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Started Echo server on port #{port}")
        # Send an :accept message so we start accepting connections once we exit this init().
        send(self(), :accept)
        {:ok, %__MODULE__{listen_socket: listen_socket}}

      {:error, reason} ->
        # Abort, we can't start the server if we can't listen to that port.
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:accept, %__MODULE__{listen_socket: listen_socket} = state) do
    # Attempt to accept incoming connections.
    case :gen_tcp.accept(listen_socket, 2_000) do
      {:ok, socket} ->
        # Create a Connection GenServer and hand over our active connection from the
        # controlling process to it.
        {:ok, pid} =
          Connection.start_link(%{socket: socket})

        :ok = :gen_tcp.controlling_process(socket, pid)
        # Remember to keep accepting more connections.
        send(self(), :accept)
        {:noreply, state}

      {:error, :timeout} ->
        # Just try again if we time out.
        send(self(), :accept)
        {:noreply, state}

      {:error, reason} ->
        # Shut down the server otherwise.
        {:stop, reason, state}
    end
  end
end
