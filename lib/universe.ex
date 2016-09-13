require Logger
defmodule AmbientSup do
  use Supervisor

  def start_link() do
    Supervisor.start_link(
     __MODULE__, :ok)
  end

  def init(:ok) do
    Logger.info Functions.red("AmbientSUp.init called")
    children = [
      # worker(Ambient.Discovery, [], [name: :AmbientDiscovery]),
    ]
    supervise(children, strategy: :one_for_one)
  end
end
defmodule DiscoverySup do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    Functions.write_red("DiscoverSup.init called")
    children = [
      #worker(Task, [fn -> end]),
      worker(Ambient.Discovery, [], [name: :AmbientDiscovery]),
      worker(Task, [fn -> :timer.sleep(1); Ambient.Discovery.register() end], id: :t1),
      #worker(Task, [fn -> :timer.sleep(4); Ambient.Discovery.loop() end], id: :t22),
    ]
    supervise(children, strategy: :one_for_one)
  end
end
defmodule Universe.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(
     __MODULE__, [], name: Universe.Supervisor)
  end
  def discover() do
    nodes = ExSlp.Service.discover()
    result = Enum.filter(
      nodes,
      fn node ->
        case ExSlp.Service.connect(node) do
          # see http://elixir-lang.org/docs/stable/elixir/Node.html#connect/1
          :ignored ->
            # Node.connect() ignored a down host
            Logger.info("Connection to #{inspect node} ignored")
          false ->
            # Connection failed
            Logger.info("Connection to #{inspect node} failed")
            nil
          true ->
            # Connection successful (but not necessarily new)
            node
        end
      end)
      msg = Functions.red("SLP Discovery: ")
      Logger.info msg <> "#{inspect result}"
  end
  def init([]) do
    Functions.write_red("Universe.init called")
    children = [
     #supervisor(DiscoverySup, []),
     #worker(Ambient.Discovery, [], [name: :AmbientDiscovery]),
     #supervisor(Task.Supervisor, [[name: Universe.TaskSupervisor]]),
      worker(
       Task, [
          fn->
            {:ok, result} = ExSlp.Service.register()
            Logger.info Functions.red("Ran registration task:")<>" ok"
          end],
        id: :SLPNodeRegister,
        restart: :transient),
      worker(
        Task, [ &discover/0 ],
        restart: :permanent,
        ),
    ]
    result = supervise(children, strategy: :one_for_one)
    #Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
    #  :timer.sleep(100)
    #  IO.puts("wonka")
    #end)
    result
  end
end
