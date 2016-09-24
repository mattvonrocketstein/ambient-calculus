require Logger

defmodule Universe do

  @doc """
  """
  def ambient_spec(ambient_name) when is_atom(ambient_name) do
    import Supervisor.Spec
    worker(
      Ambient,
      [ambient_name],
      id: ambient_name,
      restart: :transient)
  end

  @doc """
  """
  def start_ambient(ambient_name) do
    Supervisor.start_child(
      Universe.Supervisor, ambient_spec(ambient_name))
  end

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
    ambients = Ambient.Topology.filter(
      fn ambient -> name == Ambient.name(ambient)
      end)
    ambients = Map.values(ambients)
    case Enum.fetch(ambients, 0) do
      {:ok, result} -> result
      :error -> nil
    end
  end
end

defmodule Universe.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(
    __MODULE__, [],
      name: __MODULE__)
  end

  def init([]) do
    Functions.write_red("Universe.init called")
    display_children = case Display.enabled?() do
      true ->
        [ supervisor(Display.Supervisor, []) ]
        false->
        []
    end
    children = display_children ++ [
      supervisor(Discovery.Supervisor, []),
      # periodic worker worker who starts the registration agent
      worker(
        Ambient,
        [Node.self()],
        restart: :transient),
    ]
    opts = [
      strategy: :one_for_one,
      name: Universe.Supervisor]
    supervise(children, opts)
  end
end
