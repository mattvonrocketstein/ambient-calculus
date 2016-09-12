# See http://elixir-lang.org/docs/stable/elixir/Application.html
# for more information on OTP Applications
defmodule Functions do
  def noop(), do: :NOOP
  def red(msg), do: IO.ANSI.red()<>msg<>IO.ANSI.reset()
  def write_red(msg), do: IO.puts(Functions.red(msg))
end
defmodule Ambient.Algebra do
  @doc """
  An opening capability, open m, can be used in the action: "open m.P"
  This action provides a way of dissolving the boundary of an ambient named m located at
   the same level as open, according to the rule:

   An open operation may be upsetting to both P and Q above. From the point of view of
   P, there is no telling in general what Q might do when unleashed. From the point of
   view of Q, its environment is being ripped open. Still, this operation is relatively
    well-behaved because:

     (1) the dissolution is initiated by the agent open m. P, so that the
         appearance of Q at the same level as P is not totally unexpected;
    (2) open m is a capability that is given out by m, so m[Q] cannot be
        dissolved if it does not wish to be (this will become clearer later in
        the presence of communication primitives).

   TODO:
    If no ambient m can be found, the operation blocks until a time when such an ambient exists.
    If more than one ambient m exists, any one of them can be chosen.
  """
  def open(n) do
    IO.puts("closing #{Ambient.name(n)}")
    parent = Ambient.parent(n)
    namespace = Ambient.namespace(n)
    Ambient.update(parent,namespace)
    :ok = Agent.stop(n, :opened)
    parent
  end

  @doc """
  An exit capability, out m, can be used in the action: "out m.P"
  which instructs the ambient surrounding out m. P to exit its parent ambient
  named m.
  TODO:
    If the parent is not named m, the operation blocks until a time when such a parent
     exists.
"""
  def exit(n) do
    parent = Ambient.parent(n)
    Ambient.push(n, :parent, Ambient.parent(parent))
    Ambient.pop(parent, Ambient.name(n))
  end
end

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
  def get(ambient, var) do
    Ambient.get(ambient)[Ambient.to_atom(var)]
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
  def enter(n, m, prog \\ Functions.noop) do
    Ambient.push(n, :parent, m)
    Ambient.push(m, Ambient.get(n, :name), n)
  end

  @doc """
  """
  def namespace(ambient) do
    namespace = Ambient.get(ambient)
    {_val, namespace} = namespace|>Map.pop(:parent)
    {_val, namespace} = namespace|>Map.pop(:name)
    namespace
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
       Map.merge(namespace, new_namespace, fn _k, v1, v2 ->
         v2
       end)
     end)

  end
  @doc """
  Pushes `value` into the ambient.
  """
  def push(ambient, var, value) do
    var = Ambient.to_atom(var)
    Agent.update(ambient, fn namespace -> Map.put(namespace, var, value) end)
  end

  @doc """
  Pops a value from the `ambient`.

  Returns `{:ok, value}` if there is a value
  or `:error` if the hole is currently empty.
  """
  def pop(ambient, var) do
    Agent.get_and_update(ambient,
      fn namespace ->
        {_val, new_namespace} = Map.pop(namespace, var)
      end)
    end
end
