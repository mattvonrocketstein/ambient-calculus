require Logger

defmodule Universe do
  defmodule Registration do
    def sync_globals() do
      #:timer.sleep(1000)
      #{:ok, registrar} = Ambient.Registration.default()
      #registrations = Ambient.Registration.get(
      #  registrar)
      #Enum.map(registrations, fn {k,v} ->
      #  :global.register_name(k, Map.get(v, :pid))
      #end)
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
  """
end

defmodule Universe.Supervisor do

  use Supervisor
  def discovery_children() do
    [
    # a periodic task for (re)registering with the OpenSLP daemon
    # hint: run "sudo /etc/init.d/slpd start"
    worker(
      Task, [&Discovery.register/0],
      id: :SLPNodeRegister,
      restart: :permanent),

    # a periodic task for discovering other registered elixir nodes
    worker(
      Task, [ &Discovery.discover/0 ],
      id: SLPNodeDiscover,
      restart: :permanent,
      ),]
  end
  def registration_children() do
    children = [
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
      discovery_children() ++
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
    display_flag = Display.enabled?()
    Logger.info "  display: #{inspect display_flag}"
    children = if(
      display_flag, do:
          [worker(Task, [fn ->
            Enum.map(
              0..10, fn _ ->
                  Display.display()
                  :timer.sleep(1000)
                end)
          end],
          id: :sleeper,
          restart: :permanent)],
        else:
          []
        )
    children
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
