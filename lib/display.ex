require Logger
defmodule Display do
  def enabled?() do
    Application.get_env(
      :ambientcalculus,
      :display_loop,
      false)

  end
  def display_cluster_members() do
    Logger.info "ClusterMembers: " <> Enum.join(Ambient.Topology.cluster_members,", ")
  end
  def display_serial_number() do
    version = Functions.version(Ambient)
    Logger.info "System version #{inspect version}"
  end
  def display_neighborhood() do
    header = ""#step #{Functions.red inspect x} for "
    node_name = Atom.to_string(Node.self())
    header= header <> "Neighborhood[#{Functions.red node_name}]"
    Logger.info header
  end
  def display_nonlocal() do
    Logger.info "External Data:"
    ambients = :pg2.get_members(:ambients)
    results = ambients
    |> Enum.filter(fn ambient ->
      not Ambient.local?(ambient) end)
    |> Enum.map(fn ambient ->
        {Ambient.name(ambient), Ambient.Formatter.format(ambient)}
      end)
    |> Enum.into(Map.new)
    Apex.ap results
  end
  def display_local_data() do
    Logger.info "Local Data:"
    ambients = :pg2.get_members(:ambients)
    result = ambients
    |> Enum.map(fn ambient->
      case Ambient.local?(ambient) do
        true ->
          {Ambient.name(ambient), Ambient.Formatter.format(ambient)}
        false ->
          nil
      end
    end)
    |> Enum.filter(fn x-> x != nil end)
    |> Enum.into(Map.new)
    Apex.ap result
  end

  def display(delta\\1000) do
    :timer.sleep(delta)
    display_serial_number()
    display_neighborhood()
    display_cluster_members()
    display_local_data()
    display_nonlocal()
  end
end
