require Logger
defmodule Ambient.Topology do
  @doc """
  Returns a list of atoms that represent other
  elixir VMs accessible to this runtime
  """
  def cluster_members() do
    # returns a list of atoms
    Node.list()
  end

end
