require Logger
import Apex.AwesomeDef
defmodule Universe.Registration do
  def sync_globals() do
    {:ok, registrar} = Ambient.Registration.default()
    registrations = Ambient.Registration.get(
      registrar)
    Enum.map(registrations, fn {k,v} ->
      :global.register_name(k, Map.get(v, :pid))
    end)
  end

end
defmodule Ambient.Registration do
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
      tmp=node_to_name(node_name)
      pid = :global.whereis_name(tmp)
      case pid do
        :undefined ->
          msg = "no such name: #{tmp}"
          IO.puts(msg)
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
    Logger.info msg <> "started"
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
    {:ok, put(registrar, name, :pid, ambient)}
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
