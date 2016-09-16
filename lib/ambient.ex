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
    "Ambient[#{inspect Ambient.get_name(ambient)}]"
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
    string_name = Atom.to_string(atom_name)
    registration_pid = Ambient.Registration.myself()
    msg = Functions.red("Ambient[#{string_name}].start_link: ")
    case registration_pid != nil && Process.alive?(registration_pid) do
      false ->
        Logger.warn ("Registration must be started before ambients can be created.  pid #{registration_pid}")
        System.halt(1)
      true ->
        Logger.info "Starting ambient: #{[string_name]}"
        sup_pid = cond do
          sup_pid == nil ->
            Logger.info msg <> "creating my supervisor "
            {:ok, sup_pid} = Ambient.Supervisor.start_link(atom_name)
            sup_pid
          true ->
            sup_pid
        end
        namespace = Map.new
        |> Map.put(:parent, parent)
        |> Map.put(:super, sup_pid)
        |> Map.put(:name, atom_name)
        {:ok, pid} = Agent.start_link(
          fn -> namespace end,
          name: atom_name)
        Ambient.Registration.register(atom_name, pid)
        :global.register_name(atom_name, pid)
        Logger.info msg<>"finished"
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
    {_val, namespace} = namespace |> Map.pop(:parent)
    {_val, namespace} = namespace |> Map.pop(:name)
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