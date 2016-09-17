require Logger
defmodule AmbientData do
  defstruct(name: :"UnknownAmbient",
    parent: nil,
    registrar: nil,
    super: nil,
    pid: nil,
    node: :"UnknownNode",
    namespace: %{},
    ambients: %{},
    programs: [],
    )
end

defmodule Ambient do
  @moduledoc """
  """

  @doc """
  Consults the registry to return an ambient with the given name or nil
  """
  def to_string(ambient) when is_pid(ambient) do
    name = Ambient.get_name(ambient)
    num_progs = Ambient.Algebra.count(ambient)
    "<Ambient:#{inspect name} progs=[#{inspect num_progs}]>]"
  end

  @doc """
  Starts a Ambient with the given `name`.
  The name is given as a name so we can identify
  the ambient by name instead of using a PID.
  """

  def start_link(_any)
  def start_link([name | name_list]) do
    {:ok, pid} = start_link(name)
    case Enum.empty?(name_list) do
      true -> {:ok, pid}
      false -> start_link(name_list)
    end
  end
  def start_link(string_name) when is_bitstring(string_name) do
    start_link(String.to_atom(string_name))
  end
  def start_link(atom_name) when is_atom(atom_name) do
    string_name = Atom.to_string(atom_name)
    {:ok, registrar} = Ambient.Registration.default()
    msg = Functions.red("Ambient[#{string_name}].start_link: ")
    case registrar != nil && Process.alive?(registrar) do
      false ->
        Logger.error ("Registration must be started before ambients can be created.  pid #{registrar}")
        System.halt(1)
      true ->
        Logger.info "Starting ambient: #{[string_name]}"
        Logger.info msg <> "creating my supervisor "
        {:ok, sup_pid} = Ambient.Supervisor.start_link(atom_name)
        ambient_data = %AmbientData{
          parent: nil,
          registrar: registrar,
          super: sup_pid,
          name: atom_name,
          node: Node.self(),
          namespace: %{}
        }
        {:ok, pid} = Agent.start(
          fn -> ambient_data end,
          name: atom_name)
        Ambient.Registration.register(registrar, atom_name, pid)
        Logger.info msg<>"finished"
        {:ok, pid}
    end
  end

  @doc """
  Gets all the data currently in `ambient`.
  """
  def get(ambient) when Kernel.is_pid(ambient) do
    #case Process.alive?(ambient) do
    #  true ->
        Agent.get(ambient, fn ambient_data -> ambient_data end)
    #  false ->
    #    %{}
    #  end
  end

  def get_from_ambient(ambient, var) do
    Agent.get(ambient, fn ambient_data -> Map.get(ambient_data, var) end)
  end

  def namespace(ambient) do
    get_from_ambient(ambient, :namespace)
  end

  @doc """
  Return value of `var` according to `ambient`
  """
  def get_from_namespace(ambient, var) do
    Agent.get(ambient, fn ambient_data ->
      Map.get(Map.get(ambient_data, :namespace), var)
    end)
  end

  @doc """
  Writes a new value of `var` for `ambient`
  """
  def put(ambient, var, val) do
    namespace = ambient
    |> Ambient.namespace()
    |> Map.put(var, val)
    Agent.update(ambient, fn ambient_data ->
      %{ambient_data | namespace: namespace}
    end)
  end
  def push(ambient, var, val), do: put(ambient, var, val)

  def pop(ambient, var) do
    namespace = Ambient.namespace(ambient)
    {_val, namespace} = namespace |>  Map.pop(var)
    Agent.update(ambient,
      fn ambient_data ->
        %{ambient_data | namespace: namespace}
      end)
  end

  def parent(ambient), do: get_parent(ambient)
  def get_parent(ambient), do: get_from_ambient(ambient, :parent)

  def name(ambient), do: get_from_ambient(ambient, :name)
  def get_name(ambient), do: Ambient.name(ambient)
  def get_supervisor(ambient), do: Ambient.get_from_ambient(ambient, :super)

  def get_registrar(ambient), do: get_from_ambient(ambient, :registrar)
  def get_node(ambient), do: get_from_ambient(ambient, :node)
  def node(ambient), do: get_node(ambient)
  def get_ambients(ambient), do: get_from_ambient(ambient, :ambients)
  def children(ambient), do: get_ambients(ambient)

  @doc """
  Returns an answer for whether this ambient is
  healthy.  This can be hard to determine, depending
  on whether the ambient is remote or not
  """
  def health_issues(ambient) do
    ambient = lookup(ambient)
    issues = []
    case Ambient.local?(ambient) do
      true ->
        if not Process.alive?(ambient) do
          issues = issues ++ ["local process is not alive"]
        end
      false ->
        node = Ambient.node(ambient)
        respond_to = self()
        Node.spawn_link(node, fn ->
          send respond_to, Process.alive?(ambient)
        end)
        receive do
          aliveness ->
            case aliveness do
              true ->
                :noop
              false ->
                issues = issues ++ ["remote node reports process is not alive"]
            end
        after 2_000 ->
          issues = issues ++ ["timeout asking remote node if process is alive"]
        end
    end
    issues
  end

  def healthy?(ambient) do
    Enum.empty?(health_issues(ambient))
  end
  def local?(ambient) do
    Node.self()==get_from_ambient(ambient, :node)
  end
  def lookup(pid) when is_pid(pid) do
    pid
  end
  def lookup(name) when is_atom(name) do
    lookup(:global.whereis_name(name))
  end

  @doc """
  Remove sub-ambient `ambient2` from parent `ambient1`
  """
  def remove_ambient(nil, ambient2) do
    Ambient.Registration.deregister(
      Ambient.get_registrar(ambient2),
      ambient2)
  end
  def remove_ambient(ambient1, ambient2) do
    ambient1 = (is_pid(ambient1) && ambient1) || lookup(ambient1)
    ambient2 = (is_pid(ambient2) && ambient2) || lookup(ambient2)
    Agent.update(ambient1, fn ambient_data ->
      %{ambient_data | ambients: Enum.into(
        Enum.filter(
          Ambient.get_ambients(ambient1),
          fn {_name, pid} -> pid != ambient2 end),
        Map.new) }
    end)
  end
  defp add_ambient(new_parent, ambient) do
    Agent.update(new_parent, fn ambient_data ->
      ambients = Map.get(ambient_data, :ambients)
      |> Map.put(Ambient.name(ambient), ambient)
      %{ambient_data | ambients: ambients}
    end)
  end
  def reset_parent(ambient, new_parent) do
    ambient = (is_pid(ambient) && ambient) || lookup(ambient)
    new_parent = (is_pid(new_parent) && new_parent) || lookup(new_parent)
    ambient_name = Ambient.name(ambient)
    current_parent = Ambient.get_parent(ambient)
    Ambient.remove_ambient(current_parent, ambient)
    add_ambient(new_parent, ambient)
    set_parent(ambient, new_parent)
  end
  defp set_parent(ambient,new_parent) do
    Agent.update(
      ambient,
      fn ambient_data ->
        %{ambient_data|parent: new_parent}
      end)
  end

end
