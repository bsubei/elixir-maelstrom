defmodule MaelstromTutorial.EchoServer.Node do
  alias MaelstromTutorial.Message.Types

  @all_keys [:node_id, :node_ids, :current_msg_id]
  @enforce_keys @all_keys
  defstruct @all_keys

  @type t :: %__MODULE__{
          node_id: Types.node_id_t() | nil,
          node_ids: list(Types.node_id_t()) | nil,
          current_msg_id: Types.msg_id_t()
        }

  @spec new() :: t()
  def new() do
    %__MODULE__{node_id: nil, node_ids: nil, current_msg_id: 0}
  end
end
