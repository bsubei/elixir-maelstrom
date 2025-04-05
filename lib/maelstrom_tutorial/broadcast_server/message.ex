defmodule MaelstromTutorial.BroadcastServer.Message do
  require Logger

  defmodule Types do
    @type msg_id_t() :: integer()
    @type node_id_t() :: String.t()
  end

  @all_keys [:src, :dest, :body]
  @enforce_keys @all_keys
  @derive [Poison.Encoder]
  defstruct @all_keys

  @type t :: %__MODULE__{
          src: Types.node_id_t(),
          dest: Types.node_id_t(),
          body: Body.t()
        }

  @doc ~S"""
    Decodes the given JSON-encoded string into a Message object.

    ## Examples

        iex> iodata = ~s({"src":"c0","dest":"n1","body":{"type":"error","text":"dunno","in_reply_to":2,"code":42}})
        iex> %MaelstromTutorial.BroadcastServer.Message{src: "c0", dest: "n1", body: %MaelstromTutorial.BroadcastServer.Message.Body.Error{type: "error", in_reply_to: 2, code: 42, text: "dunno"}} = MaelstromTutorial.BroadcastServer.Message.decode(iodata)
        iex> iodata == MaelstromTutorial.BroadcastServer.Message.encode(MaelstromTutorial.BroadcastServer.Message.decode(iodata))
        true

  """
  @spec decode(iodata()) :: __MODULE__.t()
  def decode(input) do
    # First decode to a plain map with atom keys so we can pass them into struct().
    # map = Poison.decode!(input, keys: :atoms!)
    # TODO this is a giant memory leak problem (allocating atoms based on arbitrary string input)! I've spent too much time already on parsing so I'll leave this for now. Eventually, get the above form to work correctly without getting those inconsistent errors.
    map = Poison.decode!(input, keys: :atoms)

    # Then manually create the body struct with the required fields
    body_map = map[:body]
    body_type = __MODULE__.Body.type_str_to_module(body_map[:type])
    body_struct = struct(body_type, body_map)

    # Create the final struct with all required fields
    struct(__MODULE__, src: map[:src], dest: map[:dest], body: body_struct)
  end

  @doc ~S"""
    Encodes the given Message object into a JSON-encoded string.

    ## Examples

        iex> msg = %MaelstromTutorial.BroadcastServer.Message{src: "c0", dest: "n1", body: %MaelstromTutorial.BroadcastServer.Message.Body.Error{type: "error", in_reply_to: 2, code: 42, text: "dunno"}}
        iex> ~s({"src":"c0","dest":"n1","body":{"type":"error","text":"dunno","in_reply_to":2,"code":42}}) = MaelstromTutorial.BroadcastServer.Message.encode(msg)
        iex> msg == MaelstromTutorial.BroadcastServer.Message.decode(MaelstromTutorial.BroadcastServer.Message.encode(msg))
        true
        iex> msg = %MaelstromTutorial.BroadcastServer.Message{src: "c0", dest: "n1", body: %MaelstromTutorial.BroadcastServer.Message.Body.Broadcast{type: "broadcast", message: 22, msg_id: 555}}
        iex> ~s({"src":"c0","dest":"n1","body":{"type":"broadcast","msg_id":555,"message":22}}) = MaelstromTutorial.BroadcastServer.Message.encode(msg)
        iex> msg == MaelstromTutorial.BroadcastServer.Message.decode(MaelstromTutorial.BroadcastServer.Message.encode(msg))
        true

  """
  @spec encode(__MODULE__.t()) :: binary()
  def encode(message) do
    Poison.encode!(message)
  end

  defmodule Body do
    @type t ::
            Init.t()
            | InitOk.t()
            | Topology.t()
            | TopologyOk.t()
            | Broadcast.t()
            | BroadcastOk.t()
            | Read.t()
            | ReadOk.t()
            | Error.t()

    @doc ~S"""
      This is where we define the mapping between a body message's type as a string and the corresponding module.
    """
    @spec type_str_to_module(String.t()) :: t()
    def type_str_to_module(type) do
      case type do
        "init" -> __MODULE__.Init
        "init_ok" -> __MODULE__.InitOk
        "topology" -> __MODULE__.Topology
        "topology_ok" -> __MODULE__.TopologyOk
        "broadcast" -> __MODULE__.Broadcast
        "broadcast_ok" -> __MODULE__.BroadcastOk
        "read" -> __MODULE__.Read
        "read_ok" -> __MODULE__.ReadOk
        "error" -> __MODULE__.Error
        _ -> raise "Unknown message type: #{type}"
      end
    end

    defmodule Init do
      @all_keys [:type, :msg_id, :node_id, :node_ids]
      @enforce_keys @all_keys
      @derive [Poison.Encoder]
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              msg_id: Types.msg_id_t(),
              node_id: Types.node_id_t(),
              node_ids: list(Types.node_id_t())
            }
    end

    defmodule InitOk do
      @all_keys [:type, :msg_id, :in_reply_to]
      @enforce_keys @all_keys
      @derive [Poison.Encoder]
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              msg_id: Types.msg_id_t(),
              in_reply_to: Types.msg_id_t()
            }

      @spec new(Types.msg_id_t()) :: t()
      def new(in_reply_to) do
        %__MODULE__{type: "init_ok", msg_id: 0, in_reply_to: in_reply_to}
      end
    end

    defmodule Topology do
      @all_keys [:type, :topology, :msg_id]
      @enforce_keys @all_keys
      @derive [Poison.Encoder]
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              topology: %{Types.node_id_t() => list(Types.node_id_t())},
              msg_id: Types.msg_id_t()
            }
    end

    defmodule TopologyOk do
      @all_keys [:type, :in_reply_to, :msg_id]
      @enforce_keys @all_keys
      @derive [Poison.Encoder]
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              in_reply_to: Types.msg_id_t(),
              msg_id: Types.msg_id_t()
            }

      @spec new(Types.msg_id_t()) :: t()
      def new(in_reply_to) do
        %__MODULE__{type: "topology_ok", msg_id: 0, in_reply_to: in_reply_to}
      end
    end

    defmodule Broadcast do
      @all_keys [:type, :message, :msg_id]
      @enforce_keys @all_keys
      @derive [Poison.Encoder]
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              message: String.t(),
              msg_id: Types.msg_id_t()
            }
    end

    defmodule BroadcastOk do
      @all_keys [:type, :in_reply_to, :msg_id]
      @enforce_keys @all_keys
      @derive [Poison.Encoder]
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              in_reply_to: Types.msg_id_t(),
              msg_id: Types.msg_id_t()
            }

      @spec new(Types.msg_id_t()) :: t()
      def new(in_reply_to) do
        %__MODULE__{type: "broadcast_ok", msg_id: 0, in_reply_to: in_reply_to}
      end
    end

    defmodule Read do
      @all_keys [:type, :msg_id]
      @enforce_keys @all_keys
      @derive [Poison.Encoder]
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              msg_id: Types.msg_id_t()
            }
    end

    defmodule ReadOk do
      @all_keys [:type, :messages, :in_reply_to, :msg_id]
      @enforce_keys @all_keys
      @derive [Poison.Encoder]
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              messages: list(integer()),
              in_reply_to: Types.msg_id_t(),
              msg_id: Types.msg_id_t()
            }

      @spec new(list(integer()), Types.msg_id_t()) :: t()
      def new(messages, in_reply_to) do
        %__MODULE__{type: "read_ok", messages: messages, msg_id: 0, in_reply_to: in_reply_to}
      end
    end

    defmodule Error do
      @all_keys [:type, :in_reply_to, :code, :text]
      @enforce_keys @all_keys
      @derive [Poison.Encoder]
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              in_reply_to: Types.msg_id_t(),
              code: integer(),
              text: String.t()
            }
    end
  end
end
