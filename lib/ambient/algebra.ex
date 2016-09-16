require Logger

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
"""
  def exit(ambient, parent\\nil) do
    parent = parent || Ambient.parent(ambient)
    if (parent !=  Ambient.parent(ambient)) do
      #TODO:
      #  If the parent is not named m, this operation should block
      #  until a time when such a parent exists.
      Functions.NOOP
    end
    Ambient.push(ambient, :parent, Ambient.parent(parent))
    Ambient.pop(parent, Ambient.name(ambient))
    ambient
  end
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
  Adds program `p` to the set of concurrent programs executing inside `ambient`.
  (Implementation: adding `p` to the child-list for the supervisor of `ambient`)

  """
  def add_program(ambient, p) do
    msg = "Adding program [#{inspect p}] to "
    msg = msg <> "[#{inspect Ambient.to_string(ambient)}]"
    Logger.info msg
    super_pid = Ambient.get_supervisor(ambient)
    # FIXME: is this spec correct?
    #Ambient.Supervisor.add_child(
    #  super_pid,
    #  Task([fn -> p end]))
  end

end