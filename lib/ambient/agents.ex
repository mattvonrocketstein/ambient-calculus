defmodule Ambient do
  @moduledoc """
  """

  @doc """
  Starts a Ambient with the given `name`.

  The name is given as a name so we can identify
  the ambient by name instead of using a PID.
  """
  def start_link(name, :toplevel) do
    {:ok, pid} = Agent.start_link(fn -> %{} end, name: Ambient.to_atom(name))
    {:ok, pid}
  end

  def start_link(name, parent \\ nil) do
    parent = parent|| Ambient.TopLevel.get()
    namespace = %{}
    |> Map.put(:parent, parent)
    |> Map.put(:name, name)
    {:ok, pid} = Agent.start_link(
      fn -> namespace end,
      name: Ambient.to_atom(name))
    IO.puts "Started ambient: #{inspect [name,pid]}"
    {:ok, pid}
  end

  @doc """
  Get the data currently in the `ambient`.
  """
  def get(ambient) do
    Agent.get(ambient, fn namespace -> namespace end)
  end
  @doc """
  Return value of `var` inside of this ambient
  """
  def get(ambient, var) do
    Ambient.get(ambient)[Ambient.to_atom(var)]
  end
  def put(ambient, var, val) do
    Agent.update(ambient, fn namespace -> Map.put(namespace, var, val) end)
  end
  def get_parent(ambient) do
     Map.get(Ambient.get(ambient), :parent) || Ambient.TopLevel.get()
  end
  def parent(ambient), do: Ambient.get_parent(ambient)
  def get_name(ambient), do: Ambient.get(ambient, :name)
  def name(ambient), do: Ambient.get_name(ambient)

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
  def namespace(ambient) do
    namespace = Ambient.get(ambient)
    {_val, namespace} = namespace|>Map.pop(:parent)
    {_val, namespace} = namespace|>Map.pop(:name)
    namespace
  end

  def push(ambient, var, val) do
    Agent.get_and_update(ambient,
      fn namespace ->
        Map.put(namespace,var,val)
      end)
  end

  def pop(ambient, var) do
    Agent.get_and_update(ambient,
      fn namespace ->
        Map.pop(namespace, var)
      end)
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
