# TODO pull this out into its own package(?) so I can eventually reuse it across different server implementations.
defmodule Echo.Message do
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

  defmodule Body do
    @type t :: Init.t() | InitOk.t() | Echo.t() | EchoOk.t() | Error.t()

    @doc ~S"""
      This is where we define the mapping between a body message's type as a string and the corresponding module.
    """
    @spec type_str_to_module(String.t()) :: t()
    def type_str_to_module(type) do
      case type do
        "init" -> Body.Init
        "init_ok" -> Body.InitOk
        "echo" -> Body.Echo
        "echo_ok" -> Body.EchoOk
        "error" -> Body.Error
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
      @all_keys [:type, :in_reply_to]
      @enforce_keys @all_keys
      @derive [Poison.Encoder]
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              in_reply_to: Types.msg_id_t()
            }
    end

    defmodule Echo do
      @all_keys [:type, :echo, :msg_id]
      @enforce_keys @all_keys
      @derive [Poison.Encoder]
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              echo: String.t(),
              msg_id: Types.msg_id_t()
            }
    end

    defmodule EchoOk do
      @mandatory_keys [:type, :echo, :in_reply_to]
      @optional_keys [msg_id: nil]
      @all_keys @mandatory_keys ++ @optional_keys
      @enforce_keys @mandatory_keys
      @derive [Poison.Encoder]
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              echo: String.t(),
              in_reply_to: Types.msg_id_t(),
              msg_id: Types.msg_id_t() | nil
            }
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

  @doc ~S"""
    Decodes the given JSON-encoded string into a Message object.

    ## Examples

        iex> iodata = ~s({"src":"c0","dest":"n1","body":{"type":"error","text":"dunno","in_reply_to":2,"code":42}})
        iex> %Echo.Message{src: "c0", dest: "n1", body: %Echo.Message.Body.Error{type: "error", in_reply_to: 2, code: 42, text: "dunno"}} = Echo.Message.decode(iodata)

  """
  @spec decode(iodata()) :: Echo.Message.t()
  def decode(input) do
    # First decode to a plain map with atom keys so we can pass them into struct().
    map = Poison.decode!(input, keys: :atoms!)

    # Then manually create the body struct with the required fields
    body_map = map[:body]
    body_type = Body.type_str_to_module(body_map[:type])
    body_struct = struct(body_type, body_map)

    # Create the final struct with all required fields
    struct(__MODULE__, src: map[:src], dest: map[:dest], body: body_struct)
  end

  @doc ~S"""
    Encodes the given Message object into a JSON-encoded string.

    ## Examples

        iex> msg = %Echo.Message{src: "c0", dest: "n1", body: %Echo.Message.Body.Error{type: "error", in_reply_to: 2, code: 42, text: "dunno"}}
        iex> ~s({"src":"c0","dest":"n1","body":{"type":"error","text":"dunno","in_reply_to":2,"code":42}}) = Echo.Message.encode(msg)
        iex> msg = %Echo.Message{src: "c0", dest: "n1", body: %Echo.Message.Body.Echo{type: "echo", echo: "well hello there", msg_id: 555}}
        iex> ~s({"src":"c0","dest":"n1","body":{"type":"echo","msg_id":555,"echo":"well hello there"}}) = Echo.Message.encode(msg)

  """
  @spec encode(Echo.Message.t()) :: binary()
  def encode(message) do
    Poison.encode!(message)
  end
end
