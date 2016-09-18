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
    name = Ambient.name(ambient)
    num_progs = Ambient.Algebra.count(ambient)
    "<Ambient:#{inspect name} progs=[#{inspect num_progs}]>]"
  end

  @doc """
  Get or start an ambient with the given name,
  returning it's pid.

  FIXME: not working cross-cluster?
  """
  def get_or_start(atom_name) do
    result = Ambient.start_link(atom_name)
    case result do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  @doc """
  Starts a Ambient with the given `name`.
  The name is given as a name so we can identify
  the ambient by name instead of using a PID.
  """
  def start_link(_any)
  def start_many([name | name_list], work_so_far\\%{}) do
    {:ok, pid} = start_link(name)
    work_so_far = Map.put(work_so_far, name, pid)
    case Enum.empty?(name_list) do
      true -> work_so_far
      false -> start_many(name_list, work_so_far)
    end
  end
  def start_link(string_name) when is_bitstring(string_name) do
    start_link(String.to_atom(string_name))
  end
  def start_link(atom_name) when is_atom(atom_name) do
    {:ok, _} = Universe.assert_unique(atom_name)
    string_name = Atom.to_string(atom_name)
    msg = Functions.red("Ambient[#{string_name}].start_link: ")
    {:ok, registrar} = Ambient.Registration.default()
    case registrar != nil && Process.alive?(registrar) do
      false ->
        Functions.fatal_error(
          "Registration must be started "<>
          "before ambients can be created.  pid #{registrar}")
      true ->
        Logger.info "Starting ambient: #{[string_name]}"
        Logger.info msg <> "creating my supervisor "
        ambient_data = %AmbientData{
          parent: nil,
          registrar: registrar,
          super: nil,
          name: atom_name,
          node: Node.self(),
          namespace: %{}
        }
        Agent.start_link(
          fn -> ambient_data end,
          name: atom_name,
          id: atom_name)
    end
  end
  def bootstrap(pid) when is_pid(pid) do
    {:ok, registrar} = Ambient.Registration.default()
    atom_name = Ambient.name(pid)
    Logger.info "Bootstrapping ambient #{inspect atom_name}"
    Ambient.Registration.register(
      registrar, atom_name, pid)
    {:ok, sup_pid} = Ambient.Supervisor.start_link(
      atom_name)
    set_super(pid, sup_pid)
    {:ok, pid}
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
    {val, namespace} = namespace |>  Map.pop(var)
    Agent.update(ambient,
      fn ambient_data ->
        %{ambient_data | namespace: namespace}
      end)
    {val, namespace}
  end

  def parent(nil), do: nil
  def parent(ambient), do: get_from_ambient(ambient, :parent)

  def name(ambient), do: get_from_ambient(ambient, :name)
  def get_supervisor(ambient), do: Ambient.get_from_ambient(ambient, :super)

  def registrar(ambient), do: get_from_ambient(ambient, :registrar)

  def node(ambient), do: get_from_ambient(ambient, :node)
  def get_ambients(ambient), do: get_from_ambient(ambient, :ambients)
  def children(ambient), do: get_ambients(ambient)

  def has_child?(ambient, name) when is_atom(name) do
    name in Map.keys(Ambient.children(ambient))
  end
  def has_child?(ambient, other) when is_pid(other) do
    other in Map.values(Ambient.children(ambient))
  end

  @doc """
  Returns an answer for whether this ambient is
  healthy.  This can be hard to determine, depending
  on whether the ambient is remote or not
  """
  def health_issues(ambient) do
    ambient = Universe.lookup(ambient)
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

        issues = issues ++ receive do
          aliveness ->
            case aliveness do
              true ->
                []
              false ->
                ["remote node reports process is not alive"]
            end
        after 2_000 ->
          ["timeout asking remote node if process is alive"]
        end
    end
    issues
  end

  def healthy?(ambient) do
    Enum.empty?(health_issues(ambient))
  end

  def remote?(ambient), do: not local?(ambient)

  def local?(ambient) do
    Node.self()==get_from_ambient(ambient, :node)
  end

  @doc """
  Remove sub-ambient `ambient2` from parent `ambient1`
  """
  def remove_ambient(nil, ambient2) do
    Ambient.Registration.deregister(
      Ambient.registrar(ambient2),
      ambient2)
  end
  def remove_ambient(ambient1, ambient2) do
    ambient1 = Universe.lookup(ambient1)
    ambient2 = Universe.lookup(ambient2)
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
    ambient = Universe.lookup(ambient)
    new_parent = Universe.lookup(new_parent)
    ambient_name = Ambient.name(ambient)
    Logger.info "setting new parent for #{inspect ambient_name}"
    current_parent = Ambient.parent(ambient)
    Ambient.remove_ambient(current_parent, ambient)
    add_ambient(new_parent, ambient)
    set_parent(ambient, new_parent)
  end
  defp set_base(ambient, var, val) do
    Agent.update(
      ambient,
      fn ambient_data ->
        Map.put(ambient_data, var, val)
      end)

  end
  defp set_parent(ambient, new_parent), do: set_base(ambient, :parent, new_parent)
  defp set_super(ambient, new_super), do: set_base(ambient, :super, new_super)

end
