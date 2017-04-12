require Logger

defmodule Discovery.Supervisor do
  use Supervisor

  def start_link do
      Supervisor.start_link(__MODULE__, [], name: __MODULE__)
    end

  def init([]) do
    children = [
      # a periodic task for discovering other registered elixir nodes
      worker(
        Task, [ &Discovery.discover/0 ],
        id: SLPNodeDiscover,
        restart: :permanent,
        ),
      # a periodic task for (re)registering with the OpenSLP daemon
      # hint: run "sudo /etc/init.d/slpd start"
      worker(
        Task, [&Discovery.register/0],
        id: :SLPNodeRegister,
        restart: :permanent)
    ]
    supervise(children, strategy: :one_for_one)
  end
end

defmodule Discovery do
  def normalize(service_string) do
    {:ok, this_hostname} = :inet.gethostname()
    # HACK:
    # by default service-strings are constructed
    # with the human-friendly system hostnames.
    String.replace(
      to_string(service_string),
      to_string(this_hostname),
      "127.0.0.1")

  end
  def discover() do
    slp_services = ExSlp.Service.discover()
    slp_services
    |> Enum.map( fn service_string ->
      normalized = normalize(service_string)
      #make sure we ignore detecting ourselves
      should_skip = normalized == Atom.to_string(Node.self())

      unless(should_skip) do
        case ExSlp.Service.connect(normalized) do
          # Node.connect() ignored a down host
          # http://elixir-lang.org/docs/stable/elixir/Node.html#connect/1
          :ignored ->
            #Logger.info("Connection to #{inspect normalized_string} ignored")
            :noop

          # the Connection failed
          false ->
            #Logger.info("Connection to #{inspect normalized_string} failed")
            :noop

          # Connection is successful
          # (but not necessarily new)
          true ->
            if Display.enabled? do
              Logger.info(Functions.red("Discovery.discover: ")<>"connected")
              Logger.info("#{inspect normalized}")
            end
        end # case
      end # unless
    end)
  end
  def register() do
    case ExSlp.Service.register() do
      {:error, "errorcode: -19"} ->
         Display.write("Registration failed")
      {:ok, _result} ->
        Display.write("Ran registration task", :ok)
        :timer.sleep(5000)
    end
  end
end
