defmodule Echo.Server do
  @moduledoc """
  Documentation for `Echo.Server`.
  """
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Print hello world when the worker starts
    IO.puts("Hello, World!")
    {:ok, %{}}
  end

end
