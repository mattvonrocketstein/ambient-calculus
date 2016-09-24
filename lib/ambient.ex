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

  use GenServer

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
  Starts a Ambient with the given `name`.
  The name is given as a name so we can identify
  the ambient by name instead of using a PID.
  """
  def start_link(_any)
  def start_link(string_name) when is_bitstring(string_name) do
    start_link(String.to_atom(string_name))
  end

  def start_link(atom_name) when is_atom(atom_name) do
    {:ok, _} = Universe.assert_unique(atom_name)
    string_name = Atom.to_string(atom_name)
    Logger.info "Starting ambient: #{[string_name]}"
    ambient_data = %AmbientData{
      parent: nil,
      #registrar: registrar,
      super: nil,
      name: atom_name,
      node: Node.self(),
      namespace: %{}
    }
    {:ok, pid} = GenServer.start_link(
      Ambient, ambient_data, name: atom_name)
    Ambient.Topology.register(pid)
    {:ok, sup_pid} = Ambient.Supervisor.create_for(pid)
    set_super(pid, sup_pid)
    {:ok, pid}
  end

  @doc """
  Gets all the data currently in `ambient`.
  """
  def get(ambient) when Kernel.is_pid(ambient) do
    #case Process.alive?(ambient) do
    #  true ->
        #Agent.get(ambient, fn ambient_data -> ambient_data end)
        GenServer.call(ambient, {:get})
    #  false ->
    #    %{}
    #  end
  end
  def get_from_ambient(ambient, var) do
    GenServer.call(ambient, {:get_from_ambient, var})
  end

  def namespace(ambient) do
    get_from_ambient(ambient, :namespace)
  end

  @doc """
  Return value of `var` according to `ambient`
  """
  def get_from_namespace(ambient, var) do
    #Agent.get(ambient, fn ambient_data ->
    #  Map.get(Map.get(ambient_data, :namespace), var)
    #end)
    GenServer.call(ambient, {:get_from_namespace, var})
  end

  @doc """
  Writes a new value of `var` for `ambient`
  """
  def put(ambient, var, val) do
    GenServer.call(ambient, {:put, var, val})
  end
  def push(ambient, var, val), do: put(ambient, var, val)

  def pop(ambient, var) do
    GenServer.call(ambient, {:pop, var})
  end

  @doc """
  Removes sub-ambient `ambient2` from parent `ambient1`
  """
  def remove_ambient(nil, _ambient2), do: :ok
  def remove_ambient(ambient1, ambient2) do
    ambient1 = Universe.lookup(ambient1)
    ambient2 = Universe.lookup(ambient2)
    GenServer.cast(ambient1, {:remove_ambient, ambient2})
  end

  def parent(nil), do: nil
  def parent(ambient), do: get_from_ambient(ambient, :parent)

  def name(ambient), do: get_from_ambient(ambient, :name)
  def get_supervisor(ambient), do: Ambient.get_from_ambient(ambient, :super)

  def registrar(ambient), do: get_from_ambient(ambient, :registrar)

  def node(ambient), do: get_from_ambient(ambient, :node)
  def children(ambient), do: get_from_ambient(ambient, :ambients)

  @doc """
  Answers whether an ambient named `name` is inside of ambient `ambient`
  """
  def has_child?(ambient, name) when is_atom(name) do
    name in Map.keys(Ambient.children(ambient))
  end
  @doc """
  Answers whether an ambient with pid `pid` is inside of ambient `ambient`
  """
  def has_child?(ambient, pid) when is_pid(pid) do
    pid in Map.values(Ambient.children(ambient))
  end

  @doc """
  Returns an answer for whether this ambient is
  healthy.  This can be hard to determine, depending
  on whether the ambient is remote or not
  """
  def health_issues(ambient) do
    ambient = Universe.lookup(ambient)
    issues = case Ambient.local?(ambient) do
      true ->
        if not Process.alive?(ambient) do
          ["local process is not alive"]
        else
          []
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

  defp add_ambient(new_parent, ambient) do
    GenServer.cast(new_parent, {:add_ambient, ambient})
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
    GenServer.call(ambient,{:set_base, var, val})
  end

  def set_namespace(ambient,new_namespace), do: set_base(ambient, :namespace, new_namespace)
  defp set_parent(ambient, new_parent), do: set_base(ambient, :parent, new_parent)
  defp set_super(ambient, new_super), do: set_base(ambient, :super, new_super)

  def handle_cast({:add_ambient, ambient}, ambient_data) do
      ambients = Map.get(ambient_data, :ambients)
      |> Map.put(Ambient.name(ambient), ambient)
      {:noreply, %{ambient_data | ambients: ambients}}
  end
  def handle_cast({:push, item}, state) do
    {:noreply, [item | state]}
  end
  def handle_cast({:remove_ambient, ambient2}, ambient_data) do
    ambients=Map.get(ambient_data, :ambients)
    |> Enum.filter(fn {_name, pid} -> pid != ambient2 end)
    |> Enum.into(Map.new)
    result = %{ ambient_data | ambients: ambients }
    {:noreply, result}
  end

  def handle_call({:get_from_namespace, var},_from, ambient_data) do
    {:reply, Map.get(ambient_data, var), ambient_data}
  end
  def handle_call({:pop, var}, _from, ambient_data) do
    namespace = ambient_data |> Map.get(:namespace)
    {val, namespace} = Map.pop(namespace, var)
    {:reply, {val, namespace}, namespace}
  end
  def handle_call({:set_base,var,val},_from,ambient_data) do
    {:reply, :ok, Map.put(ambient_data, var, val)}
  end
  def handle_call({:get},_from, ambient_data) do
    {:reply, ambient_data, ambient_data}
  end
  def handle_call( {:get_from_ambient, var}, _from, ambient_data) do
    {:reply, Map.get(ambient_data, var), ambient_data}
  end
  def handle_call({:put, var, val}, _from, ambient_data) do
    namespace = ambient_data|>Map.get(:namespace)
    |> Map.put(var, val)
     {:reply, :ok, %{ambient_data|namespace: namespace}}
  end

end
