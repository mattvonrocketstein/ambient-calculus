
defmodule Ambient.Discovery do
  require Logger
  use GenServer

  def start_link() do
      Functions.write_red("Starting Discovery")
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  def init(state) do
    Logger.info ("Ambient.Discovery.init")
    {:ok, state}
  end
  def register() do
    GenServer.call(__MODULE__, :register)
    #IO.puts("results: #{result}")
  end
  def handle_call(:register, _from, state) do
    Logger.info Functions.red("Registering node with SLP")
    {:ok, result} = ExSlp.Service.register()
    #Functions.write_red("registration result: #{inspect result}")
    {:reply, :ok, result}
  end
  def loop(count\\0) do
    :timer.sleep(4000)
    #if count==0 do
    IO.puts "running first discover task #{count}"
    #end
    discover()
    loop(count+1)
  end

  def discover(), do: GenServer.call(__MODULE__, :discover, 10000)

  def handle_call(:discover, _from, state) do
    Functions.write_red("Discovering with SLP")
    nodes = ExSlp.Service.discover()
    result = Enum.filter(
      nodes,
      fn node ->
        case ExSlp.Service.connect(node) do
          true ->
            Functions.write_red("New node: #{inspect node}")
            node
          false ->
            Functions.write_red("Old node: #{inspect node}")
            nil
        end
      end)
    {:reply, result, state}
  end
end
