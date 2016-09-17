require Logger
defmodule Ambient.Topology do
  @doc """
   Returns a hash of %{ambient_name => pid}
   The hosting node is ignored.
  """
  def nonlocal_ambients_flat() do
    Map.values(nonlocal_ambients())
    |> Enum.reduce(%{}, fn(x, acc) -> Map.merge(acc,x) end)
  end

  @doc """
  Returns a map of %{nodename => %{ambient_name => pid}}
  """
  def nonlocal_ambients() do
    Ambient.Registration.registrars()
    |> Enum.map(fn {node_atom, pid} ->
      node_data = Ambient.Registration.get(pid)
      name_to_pid_map = Enum.map(
        node_data,
        fn {ambient_name, ambient_data} ->
          {ambient_name, Map.get(ambient_data, :pid)}
        end
        )
      |> Enum.into(%{})
      {node_atom, name_to_pid_map}
    end)
    |> Enum.into(Map.new)
  end
  @doc """
  Returns a list of atoms that represent other
  elixir VMs accessible to this runtime
  """
  def cluster_members() do
    # returns a list of atoms
    Node.list()
  end

end
