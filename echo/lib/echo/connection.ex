defmodule Echo.Connection do
  use GenServer
  require Logger

  @type send_fn_t :: (:gen_tcp.socket(), iodata() ->
                        :ok
                        | {:error,
                           :closed | {:timeout, binary() | :erlang.iovec()} | :inet.posix()})

  @enforce_keys [:socket, :send_fn]
  @type t :: %__MODULE__{
          socket: :gen_tcp.socket(),
          send_fn: send_fn_t()
        }
  defstruct [
    :socket,
    :send_fn
  ]

  @spec start_link(%{
          # The socket must always be specified.
          socket: :gen_tcp.socket()
          # The send_fn is optional and will default to :gen_tcp.send/2 if not specified.
        }) :: GenServer.on_start()
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg)
  end

  @impl true
  def init(init_arg) do
    state = %__MODULE__{
      socket: Map.get(init_arg, :socket),
      # Use the :gen_tcp.send by default. This is only specified by tests.
      send_fn: Map.get(init_arg, :send_fn, &:gen_tcp.send/2)
    }

    {:ok, state}
  end

  # NOTE: because this process has taken over the :gen_tcp socket, it will intercept all the tcp messages in these handle_info functions.
  @impl true
  def handle_info(message, state)

  # Handle incoming tcp messages.
  def handle_info({:tcp, socket, data}, %__MODULE__{socket: socket} = state) do
    {:noreply, handle_new_data(state, data)}
  end

  def handle_info({:tcp_closed, socket}, %__MODULE__{socket: socket} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    Logger.error("TCP connection error: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  @spec handle_new_data(t(), iodata()) :: t()
  defp handle_new_data(%__MODULE__{} = state, data) do
    :ok = send_message_on_socket(state.socket, state.send_fn, data)
    state
  end

  @spec send_message_on_socket(:gen_tcp.socket(), send_fn_t(), iodata()) :: :ok
  def send_message_on_socket(socket, send_fn, message) do
    case send_fn.(socket, message) do
      :ok ->
        :ok

      {:error, :timeout} ->
        send_message_on_socket(socket, send_fn, message)

      # TODO is this actually ok in all cases?
      {:error, :closed} ->
        :ok
    end
  end
end
