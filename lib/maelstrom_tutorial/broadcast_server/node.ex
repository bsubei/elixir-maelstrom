defmodule MaelstromTutorial.BroadcastServer.Node do
  alias MaelstromTutorial.BroadcastServer.Message.Types

  @all_keys [:node_id, :node_ids, :current_msg_id, :messages, :my_neighbors, :unacked]
  @enforce_keys @all_keys
  defstruct @all_keys

  @type t :: %__MODULE__{
          node_id: Types.node_id_t() | nil,
          node_ids: list(Types.node_id_t()) | nil,
          current_msg_id: Types.msg_id_t(),
          messages: list(integer()),
          my_neighbors: list(Types.node_id_t()),
          unacked: MapSet.t({Types.node_id_t(), Types.msg_id_t()})
        }

  @spec new() :: t()
  def new() do
    %__MODULE__{
      node_id: nil,
      node_ids: nil,
      current_msg_id: 0,
      messages: [],
      my_neighbors: [],
      unacked: MapSet.new()
    }
  end
end
