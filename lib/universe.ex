require Logger

defmodule Universe.Supervisor do

  use Supervisor

  def start_link() do
    Supervisor.start_link(
     __MODULE__, [], name: Universe.Supervisor)
  end
  def main() do
    msg = Functions.red "Universe.main: "
    Logger.info msg<> "waiting"
  end
  def init([]) do
    Functions.write_red("Universe.init called")
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
        restart: :permanent,
        ),
      # periodic worker worker who starts the registration agent
      worker(
          Task, [&start_registration_subsystem/0 ],
          id: :startRegistrationSubsystem,
          restart: :transient),
      #worker(
      #  Task, [&build_default_ambient/0 ],
      #  id: :buildInitialAmbient,
      #  restart: :transient),
      #supervisor(Ambient.Engine, []),

      # Just an post-bootstrap entry point to experiment with the system
      worker(
        Task, [&main/0],
        id: :main,
        restart: :transient),
        # Just an post-bootstrap entry point to experiment with the system
        worker(
          Task, [fn ->
            IO.puts("sleeping");
            :timer.sleep(1000)
          end],
          id: :sleeper,
          restart: :permanent),
    ]
    opts = [strategy: :one_for_one, name: Universe.Supervisor]
    result = supervise(children, opts)
    result
  end
  def start_registration_subsystem() do
    Ambient.Registration.start_link()
    build_default_ambient()
  end
  def build_default_ambient() do
    {:ok, pid} = Ambient.start_link(:default)
  end
end
