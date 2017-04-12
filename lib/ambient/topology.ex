require Logger

defmodule Ambient.Topology do

  @doc """
  """
  defp pg2_handle() do
    :pg2.create(:ambients)
    :ambients
  end

  @doc """
  Add pid to process group
  """
  def register(pid) do
    pg2_handle()
    |> :pg2.join(pid)
  end

  @doc """
  Returns a list of atoms that represent other
  elixir VM Nodes accessible to this runtime
  """
  def cluster() do
    # returns a list of atoms
    Node.list()
  end

  @doc """
  """
  def filter(fxn) do
    pg2_handle()
    |> :pg2.get_members()
    |> Enum.filter(fxn)
    |> Enum.map(fn ambient->
      { Ambient.name(ambient),
        ambient }
    end)
    |> Enum.into(Map.new)
  end

  @doc """
  """
  def local_ambients() do
    filter(fn ambient -> local?(ambient) end)
  end

  @doc """
  """
  def nonlocal_ambients() do
    filter(fn ambient ->
      not local?(ambient) end)
  end

  def remote?(ambient), do: not local?(ambient)
  def local?(ambient) do
    Node.self() == Ambient.node(ambient)
  end

  def siblings(ambient1) do
    parent = Ambient.parent(ambient1)
    filter(fn ambient -> Ambient.parent(ambient)==parent end)
  end
end
