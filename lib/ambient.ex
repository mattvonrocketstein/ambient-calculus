require Logger

defmodule Ambient do
  @moduledoc """
  """

  @doc """
  Consults the registry to return an ambient with the given name or nil
  """
  def find(ambient_name) when is_bitstring(ambient_name) do
    Map.get(Ambient.Registration.get(), ambient_name)
  end
  def to_string(ambient) when is_pid(ambient) do
    "Ambient[#{Ambient.get_name(ambient)}]"
  end

  @doc """
  Starts a Ambient with the given `name`.

  The name is given as a name so we can identify
  the ambient by name instead of using a PID.
  """
  def start_link(name, parent\\nil, sup_pid\\nil)
  def start_link(string_name, parent, sup_pid) when is_bitstring(string_name) do
    start_link(String.to_atom(string_name), parent, sup_pid)
  end
  def start_link(atom_name, parent, sup_pid) when is_atom(atom_name) do
    name = atom_name
    registration_pid = Ambient.Registration.myself()
    case registration_pid != nil && Process.alive?(registration_pid) do
      false ->
        IO.puts("Registration must be started before ambients can be created.  pid #{registration_pid}")
        System.halt(1)
      true ->
        Logger.info "Starting ambient: #{[name]}"
        sup_pid = cond do
          sup_pid == nil ->
            msg = Functions.red("Ambient[#{name}].start_link: ")
            msg = msg <> "creating my supervisor "
            Logger.info msg
            {:ok, sup_pid} = Ambient.Supervisor.start_link(name)
            sup_pid
          true ->
            sup_pid
        end
        namespace = Map.new
        |> Map.put(:parent, parent)
        |> Map.put(:super, sup_pid)
        |> Map.put(:name, name)
        {:ok, pid} = Agent.start_link(
          fn -> namespace end,
          name: Ambient.to_atom(name))
        Ambient.Registration.register(name, pid)
        Logger.info "Finished starting ambient: #{inspect [name, pid]}"
        {:ok, pid}
    end
  end

  @doc """
  Gets all the data currently in `ambient`.
  """
  def get(ambient) when Kernel.is_pid(ambient) do
    Agent.get(ambient, fn namespace -> namespace end)
  end
  def namespace(ambient) do
    namespace = Ambient.get(ambient)
    {_val, namespace} = namespace|>Map.pop(:parent)
    {_val, namespace} = namespace|>Map.pop(:name)
    namespace
  end

  @doc """
  Return value of `var` according to `ambient`
  """
  def get(ambient, var) do
    Ambient.get(ambient)[Ambient.to_atom(var)]
  end

  @doc """
  Writes a new value of `var` for `ambient`
  """
  def put(ambient, var, val) do
    Agent.update(ambient, fn namespace -> Map.put(namespace, var, val) end)
  end
  def push(ambient, var, val), do: put(ambient, var, val)

  def pop(ambient, var) do
    Agent.get_and_update(ambient,
      fn namespace ->
        Map.pop(namespace, var)
      end)
  end

  @doc """
  Write new value of `var` for `ambient`
  """
  def parent(ambient), do: Ambient.get_parent(ambient)
  def get_parent(ambient) do
     Map.get(Ambient.get(ambient), :parent)
  end

  def name(ambient), do: Ambient.get_name(ambient)
  def get_name(ambient), do: Ambient.get(ambient, :name)

  @doc """
  Returns an answer for whether this ambient is
   at the top-level hierarchy
  """
  def is_top(ambient), do: nil == Ambient.get_parent(ambient)

  @doc """
  """
  def get_supervisor(ambient), do: Ambient.get(ambient, :super)

  @doc """
  Answers how many (concurrent) programs this ambient is running
  """
  def count(ambient) do
      Ambient.get(ambient, :super)
      |> Supervisor.count_children()
      |> Enum.count
  end

  @doc """
  Entry Capability (aka "in")
  An entry capability, in m, can be used in the action: "in m.P"
  which instructsthe ambientsurrounding in m. P to enter a sibling ambient named m.
  TODO:
    If no sibling m can be found, the operation blocks until a time when such a sibling
    exists. If more than one m sibling exists, any one of them can be chosen.
  """
  def enter(n, m, _prog \\ Functions.noop) do
    Ambient.put(n, :parent, m)
    Ambient.put(m, Ambient.get(n, :name), n)
  end

  @doc """
  """
  def to_atom(var) do
    (is_atom(var) && var) || String.to_atom(var)
  end

  @doc """
  """
  def update(ambient, new_namespace) do
     Agent.update(ambient, fn namespace ->
       Map.merge(namespace, new_namespace, fn _k, _v1, v2 ->
         v2
       end)
     end)

  end
end
