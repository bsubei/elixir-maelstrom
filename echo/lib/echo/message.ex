# TODO pull this out into its own package(?) so I can eventually reuse it across different server implementations.
defmodule Echo.Message do
  require Logger

  defmodule Types do
    @type msg_id_t() :: integer()
    @type node_id_t() :: String.t()
  end

  @all_keys [:src, :dest, :body]
  @enforce_keys @all_keys
  defstruct @all_keys

  @type t :: %__MODULE__{
          src: String.t(),
          dest: String.t(),
          body: Body.t()
        }

  defmodule Body do
    @type t :: Init.t() | InitOk.t() | Echo.t() | EchoOk.t() | Error.t()

    defmodule Init do
      @all_keys [:type, :msg_id, :node_id, :node_ids]
      @enforce_keys @all_keys
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
      defstruct @all_keys

      @type t :: %__MODULE__{
              type: String.t(),
              in_reply_to: Types.msg_id_t()
            }
    end

    defmodule Echo do
      @all_keys [:type, :echo, :msg_id]
      @enforce_keys @all_keys
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
