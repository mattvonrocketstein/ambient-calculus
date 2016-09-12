defmodule Ambient.Discovery do

  use GenServer
  @pid __MODULE__

  def get() do
    pid = Process.whereis(@pid)
    is_pid = Kernel.is_pid(pid)
    case pid do
        nil ->
          {:ok, pid} = Ambient.Discovery.start_link()
          pid
        _ ->
          pid
    end
  end
  def start_link() do
      Functions.write_red("Starting Discovery")
      GenServer.start_link(__MODULE__, [name: @pid])
  end
  def handle_cast(:register, _from) do
    Functions.write_red("Registering node with SLP")
    ExSlp.Service.register()
    {:noreply, nil}
  end

  def handle_call(:discover, _from) do
    Functions.write_red("Discovering with SLP")
    nodes = ExSlp.Service.discover()
    Enum.filter(
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
    {:reply, []}
  end
end
