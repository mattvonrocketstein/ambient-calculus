require Logger
import Apex.AwesomeDef

defmodule Entry do
  defstruct name: "UnknownAmbient", pid: nil, node: "UnknownNode"
end

defmodule Ambient.Registration do
  @doc """
   Returns a hash of %{node_name => registrar_pid}
   The hosting node is ignored.
  """
  def registrars() do
    Ambient.Topology.cluster_members()
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
  def default() do
    get_for_node(Node.self())
  end
  @doc """
  """
  def node_to_name(node_atom) do
      atom_name = String.to_atom(
        Atom.to_string(node_atom)<>"-Registry")
  end

  def get_for_node(node_name) do
      tmp = node_to_name(node_name)
      pid = :global.whereis_name(tmp)
      case pid do
        :undefined ->
          msg = "cannot find registrar: #{tmp}"
          Logger.warn msg
          {:error, msg}
        _ ->
          {:ok, pid}
      end
  end

  def start_link(node_atom) do
    name_atom = node_to_name(node_atom)
    registry = %{}
    display_name = Functions.red Atom.to_string name_atom
    msg = "Ambient.Registration[#{display_name}]"
    {:ok, pid} = result = Agent.start_link(
        fn -> registry  end,
        name: name_atom)
    Logger.info msg <> " started"
    :global.register_name(name_atom, pid)
    result
  end

  @doc """
  """
  def get_ambient(registrar, name) when is_atom(name) do
    Map.get(get(registrar, name), :pid)
  end
  def get_ambient(registrar, name) when is_bitstring(name) do
    name = String.to_atom(name)
    :global.whereis_name(name)#get_ambient(name) ||
  end

  @doc """
  """
  def map_top(registrar) do
    data = get(registrar) || %{}
    Enum.map(
          data,
          fn {atom_name, registration} ->
            {atom_name, Map.get(registration, :pid)}
          end)
  end

  @doc """
  """
  def get(nil), do: %{}
  def get(pid) when is_pid(pid) do
    Agent.get(pid,
      fn registry -> registry end)
  end
  def get(pid, name) when is_pid(pid) do
    Agent.get(pid,
      fn registry -> Map.get(registry,name) end)
  end

  @doc """
  """
  def register(registrar, name, ambient) when Kernel.is_pid(ambient) do
    %Entry{name: name, pid: ambient}
    {:ok, put(registrar, name, :pid, ambient)}
    :global.re_register_name(name, ambient)
  end

  @doc """
  Removes an ambient registration from the given registar
  NOTE: this does not by itself stop the Agent for that
  """
  def deregister(registrar, ambient_name) when is_bitstring(ambient_name) do
    ambient_name = String.to_atom(ambient_name)
    deregister(registrar, ambient_name)
  end
  def deregister(registrar, ambient_pid) when is_pid(ambient_pid) do
    ambient_name = Ambient.get_name(ambient_pid)
    deregister(registrar, ambient_name)
  end
  def deregister(registrar, name) when is_atom(name) do
    registrar = registrar || Ambient.Registration.default()
    Agent.get_and_update(
      registrar,
      fn registry ->
        {_val, updated_registry} = Map.pop(registry, name)
      end)
  end
  @doc """
  """
  def put(registrar, name, key, val) do
    Agent.update(
      registrar,
      fn registry ->
        Map.put(
          registry,
          name,
          Map.put(
            Map.get(registry, name) || %{},
            key, val))
      end)
  end
end
