require Logger

defmodule Universe do
  defmodule Registration do
    def sync_globals() do
      :timer.sleep(1000)
      {:ok, registrar} = Ambient.Registration.default()
      registrations = Ambient.Registration.get(
        registrar)
      Enum.map(registrations, fn {k,v} ->
        :global.register_name(k, Map.get(v, :pid))

      end)
    end
  end

  @doc """
  Every node gets the "default ambient", which is registered
  locally automatically, and which has the same name as
  the node itself
  """
  def start_local_ambient() do
    name = Node.self()
    {:ok, ambient} = Ambient.start_link(name)
  end

  def mainloop() do
    :timer.sleep(1)
    msg = Functions.red "Universe.main: "
    Logger.info msg <> "entry"
    {:ok, ambientA} = Ambient.start_link(:A)
    {:ok, ambientB} = Ambient.start_link(:B)
    Ambient.Algebra.enter(
      ambientB, ambientA)
  end

  @doc """
  """
  def start_registration_subsystem() do
    Ambient.Registration.start_link(Node.self())
    Universe.start_local_ambient()
  end

  @doc """
   Returns a hash of %{node_name => registrar_pid}
   The hosting node is ignored.
  """
  def all_registrars() do
    cluster_members()
    |> Enum.map(
      fn node_atom ->
        case Ambient.Registration.get_for_node(node_atom) do
          {:ok, pid} ->
            {node_atom, pid}
          {:error, _} ->
            nil
        end
      end)
    |> Enum.filter(fn x -> x != nil end)
  end

  @doc """
   Returns a hash of %{ambient_name => pid}
   The hosting node is ignored.
  """
  def nonlocal_ambients_flat() do
    Map.values(nonlocal_ambients())
    |> Enum.reduce(%{}, fn(x, acc) -> Map.merge(acc,x) end)
  end

  @doc """
  Returns a map of %{nodename => %{ambient_name => pid}}
  """
  def nonlocal_ambients() do
    all_registrars()
    |> Enum.map(fn {node_atom, pid} ->
      node_data = Ambient.Registration.get(pid)
      name_to_pid_map = Enum.map(
        node_data,
        fn {ambient_name, ambient_data} ->
          {ambient_name, Map.get(ambient_data, :pid)}
        end
        )
      |> Enum.into(%{})
      {node_atom, name_to_pid_map}
    end)
    |> Enum.into(Map.new)
  end

  #def sync_ambients() do
  #  Enum.map(
  #    nonlocal_ambients(),
  #    fn {ambient_name, ambient_pid} ->
  #      {ambient_name,
  #      :global.re_register_name(
  #        ambient_name, ambient_pid)}
  #    end)
  #end

  @doc """
  Returns a list of atoms that represent other
  elixir VMs accessible to this runtime
  """
  def cluster_members() do
    # returns a list of atoms
    Node.list()
  end

  @doc """
  """
  def display(x\\0) do
    :timer.sleep(1000)
    Logger.info "System Summary"
    IO.puts "[vsn=#{inspect Functions.version(Ambient)}]"
    header = ""#step #{Functions.red inspect x} for "
    node_name = Atom.to_string(Node.self())
    header= header <> "Neighborhood[#{Functions.red node_name}]"
    Logger.info header
    #IO.puts "this-node: #{Atom.to_string(Node.self())}"
    Logger.info "ClusterMembers: " <> Enum.join(cluster_members,", ")
    Logger.info "Local Data:"
    {:ok, registrar} = Ambient.Registration.default()
    result = Ambient.Registration.get(registrar)
    |> Enum.map(fn {aname, rdata}->
      namespace = Ambient.Registration.get_ambient(registrar, aname)
      |> Ambient.namespace()
      tmp = rdata
      |> Map.put(:namespace, namespace)
      |> Map.put(:ambients, Ambient.get_ambients(aname))
      { aname, tmp}
    end)
    |>Enum.into(%{})
    Apex.ap result
    display_nonlocal()
    #Apex.ap Universe.root_ambients()
  end
  def display_nonlocal() do
    Logger.info "Non-local Data:"
    nonlocal = nonlocal_ambients_flat()
    |> Enum.map(fn {ambient_name, pid} ->
      {Ambient.to_string(pid), Ambient.namespace(pid)}
    end)
    Apex.ap nonlocal

  end
end

defmodule Universe.Supervisor do

  use Supervisor
  def registration_children() do
    children = [
      # a one-off task for registering with the OpenSLP daemon
      # hint: run "sudo /etc/init.d/slpd start"
      worker(
        Task, [&Discovery.register/0],
        id: :SLPNodeRegister,
        restart: :transient),

      # a periodic task for discovering other registered elixir nodes
      worker(
        Task, [ &Discovery.discover/0 ],
        id: SLPNodeDiscover,
        restart: :transient,
        ),
        # periodic worker worker who starts the registration agent
        worker(
            Task, [&Universe.Registration.sync_globals/0 ],
            id: :startUniversalRegistration,
            restart: :transient),

      # periodic worker worker who starts the registration agent
      worker(
          Task, [&Universe.start_registration_subsystem/0 ],
          id: :startRegistrationSubsystem,
          restart: :transient),
    ]
  end
  def get_children() do
    children =
      registration_children() ++
      display_children ++ [

      # Just an post-bootstrap entry point to experiment with the system
      #worker(
      #  Task, [&Universe.mainloop/0],
      #  id: :main, restart: :transient),
    ]
  end

  @doc """
  if DISPLAY_LOOP not found in the environment, returns
  no children.  otherwise, returns a list consisting of
  the display worker
  """
  def display_children() do
    display_flag = System.get_env("DISPLAY_LOOP") || false
    Logger.info "  display: #{inspect display_flag}"
    children = if(
      display_flag, do:
          [worker(Task, [fn ->
            Enum.map(
              0..10, fn x ->
                  Universe.display()
                  :timer.sleep(1000)
                end)
          end],
          id: :sleeper,
          restart: :permanent)],
        else:
          []
        )
  end

  def start_link() do
    Supervisor.start_link(
     __MODULE__, [],
     name: Universe.Supervisor)
  end

  def init([]) do
    Functions.write_red("Universe.init called")
    # display loop
    children = get_children()
    opts = [
      strategy: :one_for_one,
      name: Universe.Supervisor]
    result = supervise(children, opts)
    result
  end
end
