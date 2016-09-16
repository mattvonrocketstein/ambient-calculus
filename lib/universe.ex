require Logger

defmodule Universe do

  def start_local_ambient() do
    name = Node.self()
    {:ok, ambient} = Ambient.start_link(name)
    Ambient.Registration.get_ambient(name)
    |> Ambient.put(
      :registry,
      Ambient.Registration.myself())
  end

  def mainloop() do
    msg = Functions.red "Universe.main: "
    Logger.info msg<> "entry"
  end

  @doc """
  """
  def start_registration_subsystem() do
    Ambient.Registration.start_link()
    Universe.start_local_ambient()
  end
  def root_ambients() do
    Enum.map(cluster_members(), fn node_name ->

      IO.puts "looking up #{node_name}"
      Ambient.Registration.get_ambient(node_name)
    end)
  end
  def root_registrations() do
    root_ambients()
    |> Enum.map(fn root_ambient ->
      Ambient.get(root_ambient, :registry)
    end)
  end
  def sync_registry() do
    root_registrations()
    |> Enum.map(fn pid ->
      Logger.info ("Found pid #{inspect pid} for root-reg")
      pid
      |> Ambient.Registration.get()
    end)
  end
  def cluster_members() do
    # returns a list of atoms
    Node.list()
  end
  @doc """
  """
  def display(x\\0) do
    Ambient.Registration.sync_globals()
    header = ""#step #{Functions.red inspect x} for "
    node_name = Atom.to_string(Node.self())
    header= header <> "Neighborhood[#{Functions.red node_name}]"
    IO.puts header
    #IO.puts "this-node: #{Atom.to_string(Node.self())}"
    IO.puts "ClusterMembers: " <> Enum.join(cluster_members,", ")
    IO.puts "AmbientRegistry:\n"
    result = Ambient.Registration.get()
    |> Enum.map(fn {aname, rdata}->
      namespace = Ambient.Registration.get_ambient(aname)
      |>Ambient.namespace()
      { aname,
        Map.put(
          rdata,
          :namespace,
          namespace)}
    end)
    |>Enum.into(%{})
    Apex.ap result
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
          Task, [&Universe.start_registration_subsystem/0 ],
          id: :startRegistrationSubsystem,
          restart: :transient),
    ]
  end
  def get_children() do
    children =
      registration_children() ++
      display_children

      #worker(
      #  Task, [&build_default_ambient/0 ],
      #  id: :buildInitialAmbient,
      #  restart: :transient),
      #supervisor(Ambient.Engine, []),

      # Just an post-bootstrap entry point to experiment with the system
      #worker(
      #  Task, [&Universe.mainloop/0],
      #  id: :main,
      #  restart: :transient),
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
