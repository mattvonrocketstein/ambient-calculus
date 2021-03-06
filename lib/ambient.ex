require Logger

defmodule AmbientStruct do
      defstruct(
        name:      :"UnknownAmbient", # atom representing this ambient's name
        node:      :"UnknownNode",    # atom representing the Node this ambient resides in
        parent:    nil,               # PID for parent ambient (a genserver)
        progman:   nil,               # PID for progspace manager (a supervisor)
        pid:       nil,               # PID for this ambient (a genserver)
        namespace: %{},               # %{ :var => val }
        ambients:  %{},               # %{ :ambient_name => ambient_pid }
        progspace: %{},               # %{ :program_name => task_function }
        )
    end

defmodule Ambient do

  use GenServer
  import Ambient.Topology

  @moduledoc """
  """


  @doc """
  Gets all the data currently in `ambient`.
  """
  def get(ambient) when Kernel.is_pid(ambient) do
    GenServer.call(ambient, {:get})
  end

  def get_from_ambient(ambient, var) do
    GenServer.call(ambient, {:get_from_ambient, var})
  end

  @doc """
  Returns the namespace for this ambient
  """
  def namespace(ambient) do
    get_from_ambient(ambient, :namespace)
  end

  @doc """
  Returns the value of `var` according to this ambient's namespace
  """
  def get_from_namespace(ambient, var) do
    GenServer.call(ambient, {:get_from_namespace, var})
  end

  @doc """
  Writes a new value of `var` for ambient's namespace
  """
  def put(ambient, var, val) do
    GenServer.call(ambient, {:put, var, val})
  end

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
  def progman(ambient), do: Ambient.get_from_ambient(ambient, :progman)
  def progspace(ambient), do: Ambient.get_from_ambient(ambient, :progspace)
  def node(ambient), do: get_from_ambient(ambient, :node)
  def children(ambient), do: get_from_ambient(ambient, :ambients)

  @doc """
  Answers whether an ambient (name or pid) `name`
  is inside of another ambient
  """
  def has_child?(ambient, name) when is_atom(name) do
    name in Map.keys(Ambient.children(ambient))
  end
  def has_child?(ambient, pid) when is_pid(pid) do
    pid in Map.values(Ambient.children(ambient))
  end

  @doc """
  Returns a list of complaints about this ambient's health status,
  and empty list if there are no health isses
  """
  def health_issues(ambient) do
    ambient = Universe.lookup(ambient)
    issues = []
    issues = issues ++
      case Process.alive?(ambient) do
        true  -> []
        false -> ["local process is dead"]
      end
    issues = issues ++
      case Process.alive?(Ambient.progman(ambient)) do
        true  -> []
        false -> ["progman is dead; progspace is unsupervised"]
      end
    issues
  end
  def healthy?(ambient) do
    Enum.empty?(health_issues(ambient))
  end

  defp add_ambient(new_parent, ambient) do
    GenServer.cast(new_parent, {:add_ambient, ambient})
  end
  def add_program(ambient, name, fxn) when is_atom(name) and is_function(fxn, 1) do
    IO.puts "Adding program #{inspect name} "<>
      "to ambient '#{inspect Ambient.name(ambient)}'"
    wrapper = fn -> fxn.(%{}) end
    GenServer.cast(
      ambient,
      { :add_program, name, wrapper})
  end
  def start_program(ambient, name) do
    IO.puts "Starting program #{inspect name} "<>
      "in ambient '#{inspect Ambient.name(ambient)}'"
    wrapper = Ambient.progspace(ambient)
    |>Map.get(name)
    ambient
    |> Ambient.progman()
    |> Task.Supervisor.start_child(wrapper)
  end
  defp set_base(ambient, var, val) do
    GenServer.call(ambient,{:set_base, var, val})
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

  defp set_parent(ambient, new_parent) do
    set_base(ambient, :parent, new_parent)
  end
  def set_namespace(ambient,new_namespace) do
     set_base(ambient, :namespace, new_namespace)
  end
  def set_progman(ambient, new_super) do
     set_base(ambient, :progman, new_super)
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
    ambient_data = %AmbientStruct{
      name:    atom_name,
      node:    Node.self(),
      parent:  nil,
      progman: nil,
      namespace: %{}
    }
    {:ok, pid} = GenServer.start_link(
      Ambient, ambient_data, name: atom_name)
    Ambient.Topology.register(pid)
    {:ok, sup_pid} = ProgSpace.create_for(pid)
    Ambient.set_progman(pid, sup_pid)
    {:ok, pid}
  end
  def handle_cast({:add_ambient, ambient}, ambient_data) do
      ambients = Map.get(ambient_data, :ambients)
      |> Map.put(Ambient.name(ambient), ambient)
      {:noreply, %{ambient_data | ambients: ambients}}
  end
  def handle_cast({:add_program, name, fxn}, ambient_data) do
    import Supervisor.Spec
    progspace = ambient_data
    |> Map.get(:progspace)
    |> Map.put(name, fxn)
    result = %{ ambient_data | progspace: progspace }
    {:noreply, result}
  end
  def handle_cast({:start_program, name}, ambient_data) do
    wrapper_fxn = ambient_data
    |> Map.get(:progspace)
    |> Map.get(name)
    progman = Map.get(ambient_data, :progman)
    Task.Supervisor.start_child(progman, wrapper_fxn)
    {:noreply, ambient_data}
  end
  def handle_cast({:remove_ambient, ambient2}, ambient_data) do
    ambients=Map.get(ambient_data, :ambients)
    |> Enum.filter(fn {_name, pid} -> pid != ambient2 end)
    |> Enum.into(Map.new)
    result = %{ ambient_data | ambients: ambients }
    {:noreply, result}
  end

  def handle_call({:get_from_namespace, var}, _from, ambient_data) do
    {:reply, Map.get(ambient_data, var), ambient_data}
  end
  def handle_call({:pop, var}, _from, ambient_data) do
    namespace = ambient_data |> Map.get(:namespace)
    {val, namespace} = Map.pop(namespace, var)
    {:reply, {val, namespace}, namespace}
  end
  def handle_call({:set_base,var,val}, _from, ambient_data) do
    {:reply, :ok, Map.put(ambient_data, var, val)}
  end
  def handle_call({:get}, _from, ambient_data) do
    {:reply, ambient_data, ambient_data}
  end
  def handle_call( {:get_from_ambient, var}, _from, ambient_data) do
    {:reply, Map.get(ambient_data, var), ambient_data}
  end
  def handle_call({:put, var, val}, _from, ambient_data) do
    namespace = ambient_data
    |> Map.get(:namespace)
    |> Map.put(var, val)
     {:reply, :ok, %{ambient_data|namespace: namespace}}
  end

end
