defmodule KV.Registry do
  use GenServer

  ##
  # Client API
  #

  @doc """
  Starts the registry.
  """
  def start_link(table, event_manager, buckets, opts \\ []) do
    GenServer.start_link(__MODULE__, {table, event_manager, buckets}, opts)
  end

  @doc """
  Looks up the bucket pid for `name` stored in `table`.

  Returns `{:ok, pid}` if the bucket exists, `:error` otherwise.
  """
  def lookup(table, name) do
    case :ets.lookup(table, name) do
      [{^name, bucket}] ->
        {:ok, bucket}
      [] ->
        :error
    end
  end

  @doc """
  Ensures there is a bucket associated to the given `name` in `server`.
  """
  def create(server, name) do
    GenServer.call(server, {:create, name})
  end


  ##
  # Server Callbacks
  #

  def init({table, events, buckets}) do
    refs = :ets.foldl(fn {name, pid}, acc ->
      HashDict.put(acc, Process.monitor(pid), name)
    end, HashDict.new, table)

    {:ok, %{names: table,
            refs: refs,
            events: events,
            buckets: buckets}}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call({:create, name}, _from, state) do
    case lookup(state.names, name) do
      {:ok, pid} ->
        {:reply, pid, state}
      :error ->
        {:ok, pid} = KV.Bucket.Supervisor.start_bucket(state.buckets)
        ref = Process.monitor(pid)
        refs = HashDict.put(state.refs, ref, name)
        :ets.insert(state.names, {name, pid})
        GenEvent.sync_notify(state.events, {:create, name, pid})
        {:reply, pid, %{state | refs: refs}}
    end
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    {name, refs} = HashDict.pop(state.refs, ref)
    :ets.delete(state.names, name)

    # push a notification to the event manager on exit
    GenEvent.sync_notify(state.events, {:exit, name, pid})

    {:noreply, %{state | refs: refs}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
defmodule KV.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(KV.Registry, [KV.Registry])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
################################
defmodule Ambient.Supervisor do
  @moduledoc """
  """
  use Supervisor
  #@manager_name KV.EventManager
  #@registry_name KV.Registry

 def start_link do
   Supervisor.start_link(__MODULE__, :ok)
 end

 def init(:ok) do
   Functions.write_red("Supervisor.init called")
   children = [
     #worker(Ambient, [:ambient1]),
     #worker(Ambient, [:ambient2]),
     #worker(Ambient.Discovery, []),
     worker(Task, [
       fn ->
         IO.puts "task: ok"
       end])
     #worker(Ambient.Discovery, [], [name: :AmbientDiscovery]),
     #worker(GenEvent, [[name: @manager_name]]),
     #worker(KV.Registry, [@manager_name, [name: @registry_name]])
   ]
   supervise(children, strategy: :one_for_one)
 end
end

defmodule Ambient.App do
  @moduledoc """
  """
  use Application

  @doc """
  """
  def start(:normal, [ node_name ]) do
    import Supervisor.Spec, warn: false
    IO.puts("Starting app: #{inspect node_name}")
    children = [
      #worker(Ambient, [:ambient1]),
      #worker(Ambient, [:ambient2]),
      #worker(Ambient.Discovery, []),
      worker(Task, [
        fn ->
          IO.puts "task: ok"
        end])
      #worker(Ambient.Discovery, [], [name: :AmbientDiscovery]),
      #worker(GenEvent, [[name: @manager_name]]),
      #worker(KV.Registry, [@manager_name, [name: @registry_name]])
    ]
    opts = [strategy: :one_for_one, name: KVServer.Supervisor]
    supervise(children, strategy: :one_for_one)

  end
end
#
#
#
#
###
