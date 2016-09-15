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
  def get_supervisor(ambient) do
  end
  def add_program(ambient, p) do
    msg = "Adding program [#{inspect p}] to "
    msg = msg <> "[#{inspect Ambient.to_string(ambient)}]"
    Logger.info msg
    Agent.get(
      ambient,
      fn namespace -> Map.get(namespace,:name) end)
    #ambient_super = Agent.get Ambient.Supervisor.add_child()
  end
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
end
