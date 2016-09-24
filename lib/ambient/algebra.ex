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
    Logger.info("opening #{Ambient.name(n)}")
    this_parent = Ambient.parent(n)
    this_namespace = Ambient.namespace(n)
    if this_parent==nil do
        Display.write("warning", "opening top-level ambient may have undesired effect")
        :noop
    else
          parent_namespace = Ambient.namespace(this_parent)
          |> Map.merge(this_namespace)
          Ambient.set_namespace(this_parent, parent_namespace)
          Ambient.reset_parent(n, nil)
          GenServer.stop(n)
    end
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
      raise "not implemented yet"
    end
    grandparent = Ambient.parent(parent)
    Ambient.reset_parent(ambient, grandparent)
    {:ok, grandparent}
  end
  @doc """
  Answers how many (concurrent) programs this ambient is running
  """
  def count(ambient) do
      2
      #sooper = Ambient.get_supervisor(ambient)
      #case Process.alive?(sooper) do
      #  true ->
      #    Supervisor.count_children()
      #  false ->
      #    nil
      #end
  end

  @doc """
  Entry Capability (aka "in")
  An entry capability, in m, can be used in the action: "in m.P"
  which instructsthe ambient surrounding in m. P to enter a sibling ambient named m.
  TODO:
    If no sibling m can be found, the operation blocks until a time when such a sibling
    exists. If more than one m sibling exists, any one of them can be chosen.
  """
  def enter(ambient1, ambient2, prog\\Functions.noop)
  def enter(ambient1, ambient2, prog) when is_atom(ambient1) and is_atom(ambient2) do
    enter(Universe.lookup(ambient1), Universe.lookup(ambient2), prog)
  end
  def enter(ambient1,  ambient2, _prog) when is_pid(ambient1) and is_pid(ambient2) do
    Display.write("algebra::enter",[ambient1,ambient2])
    Ambient.reset_parent(ambient1, ambient2)
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
