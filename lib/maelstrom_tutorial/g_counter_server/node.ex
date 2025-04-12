defmodule MaelstromTutorial.GCounterServer.Node do
  alias MaelstromTutorial.GCounterServer.Message.Types

  @all_keys [:node_id, :node_ids, :current_msg_id, :counters]
  @enforce_keys @all_keys
  defstruct @all_keys

  @type t :: %__MODULE__{
          node_id: Types.node_id_t() | nil,
          node_ids: list(Types.node_id_t()) | nil,
          current_msg_id: Types.msg_id_t(),
          counters: %{Types.node_id_t() => integer()}
        }

  @spec new() :: t()
  def new() do
    %__MODULE__{
      node_id: nil,
      node_ids: nil,
      current_msg_id: 0,
      counters: %{}
    }
  end
end
