defmodule MaelstromTutorial.GSetServer.Node do
  alias MaelstromTutorial.GSetServer.Message.Types

  @all_keys [:node_id, :node_ids, :current_msg_id, :gset]
  @enforce_keys @all_keys
  defstruct @all_keys

  @type t :: %__MODULE__{
          node_id: Types.node_id_t() | nil,
          node_ids: list(Types.node_id_t()) | nil,
          current_msg_id: Types.msg_id_t(),
          gset: MapSet.t(any())
        }

  @spec new() :: t()
  def new() do
    %__MODULE__{
      node_id: nil,
      node_ids: nil,
      current_msg_id: 0,
      gset: MapSet.new()
    }
  end
end
