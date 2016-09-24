require Logger

defmodule Ambient.Topology do

  defp pg2_handle() do
    :pg2.create(:ambients)
    :ambients
  end

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
  def filter(fxn) do
    result = pg2_handle()
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
    filter(fn ambient -> Ambient.local?(ambient) end)
  end
  @doc """
  """
  def nonlocal_ambients() do
    filter(fn ambient ->
      not Ambient.local?(ambient) end)
  end
end
