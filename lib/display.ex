require Logger
defmodule Display.Supervisor do

  use Supervisor

  def start_link do
      Supervisor.start_link(
        __MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      worker(Task, [fn ->
        Enum.map(
          0..10000, fn _ ->
              Display.display()
              :timer.sleep(1000)
            end)
      end],
      id: :sleeper,
      restart: :permanent)
    ]
    supervise(children, strategy: :one_for_one)
  end
end


defmodule Display do
  def enabled?() do
    Application.get_env(
      :ambientcalculus,
      :display_loop,
      false)
  end
  def display_cluster_members() do
    Logger.info "ClusterMembers: " <> Enum.join(Ambient.Topology.cluster,", ")
  end
  def display_serial_number() do
    version = Functions.version(Ambient)
    {:ok, version} = Enum.fetch(version,0)
    version = version
    |>to_string
    |>String.slice(0,7)
    Logger.info "System version #{inspect version}"
  end
  def display_neighborhood() do
    header = ""#step #{Functions.red inspect x} for "
    node_name = Atom.to_string(Node.self())
    header= header <> "Neighborhood[#{Functions.red node_name}]"
    Logger.info header
  end
  def display_nonlocal() do
    Logger.info "External Data:"
    results = Ambient.Topology.nonlocal_ambients()
    Apex.ap results
  end

  def display_local_data() do
    Logger.info "Local Data:"
    result = Ambient.Topology.local_ambients()
    Apex.ap result
  end

  def display(delta\\1000) do
    :timer.sleep(delta)
    display_serial_number()
    display_neighborhood()
    display_cluster_members()
    display_local_data()
    display_nonlocal()
  end
end
