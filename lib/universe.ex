require Logger

defmodule Universe do
  @doc """
  """
  def assert_unique(atom_name) do
    pid = Universe.lookup(atom_name)
    case pid do
      nil ->
        {:ok, atom_name}
      _ ->
        err = "Name conflict: "
        err = err <> "New #{inspect atom_name} vs "
        err = err <> "Old #{inspect pid}"
        {:error, err}
    end
  end

  @doc """
  """
  def lookup(pid) when is_pid(pid), do: pid
  def lookup(name) when is_atom(name) do
    result = :global.whereis_name(name)
    #result = :gproc.lookup_global_name(name)
    case result do
      :undefined -> nil
      _ -> result
    end
  end

  @doc """
  Every node gets the "default ambient", which is registered
  locally automatically, and which has the same name as
  the node itself
  """
  def start_local_ambient do
    {:ok, pid} = Ambient.start_link(Node.self())
  end

  @doc """
  """
  def start_registration_subsystem do
    #Ambient.Registration.start_link(Node.self())
    #:gproc.add_global_property(Node.self(),%)
    Universe.start_local_ambient()
  end
end

defmodule Universe.Supervisor do

  use Supervisor

  @doc """
  Return a list of display-related children,
  or maybe an empty list as applicable, based on Mix.env.
  Specifically, the :display_loop setting
  """
  def display_children do
    display_flag = Display.enabled?()
    #Logger.info "  display: #{inspect display_flag}"
    children = if(
      display_flag, do:
          [
            supervisor(Display.Supervisor, [])
          ],
        else:
          []
        )
    children
  end
  @doc """
  Return a list of registration-related children,
  or maybe an empty list as applicable, base on Mix.env
  """
  def registration_children do
    [
      # periodic worker worker who starts the registration agent
      worker(
          Task, [&Universe.start_registration_subsystem/0 ],
          id: :startRegistrationSubsystem,
          restart: :transient),
    ]
  end

  def start_link do
    Supervisor.start_link(
     __MODULE__, [],
     name: Universe.Supervisor)
  end

  def init([]) do
    Functions.write_red("Universe.init called")
    children = [
        supervisor(Discovery.Supervisor, []) ] ++
      registration_children() ++
      display_children
    opts = [
      strategy: :one_for_one,
      name: Universe.Supervisor]
    result = supervise(children, opts)
    result
  end
end
