require Logger
defmodule Ambient.Topology do

  def register(pid) do
    :pg2.create(:ambients)
    :pg2.join(:ambients, pid)
  end

  @doc """
  Returns a list of atoms that represent other
  elixir VM Nodes accessible to this runtime
  """
  def cluster() do
    # returns a list of atoms
    Node.list()
  end
  def filter(fxn) do
    ambients = :pg2.get_members(:ambients)
    result = ambients
    |> Enum.filter(fxn)
    |> Enum.map(fn ambient->
      { Ambient.name(ambient),
        Ambient.Formatter.format(ambient) }
    end)
    |> Enum.into(Map.new)
  end

  @doc """
  """
  def local_ambients() do
    filter(fn ambient -> Ambient.local?(ambient) end)
  end
  @doc """
  """
  def nonlocal_ambients() do
    filter(fn ambient ->
      not Ambient.local?(ambient) end)
  end
end
