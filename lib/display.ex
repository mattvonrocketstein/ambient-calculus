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
    Logger.info "Non-local Data:"
    nonlocal = Ambient.Topology.nonlocal_ambients_flat()
    |> Enum.map(fn {ambient_name, pid} ->
      #data = Map.new()
      #|> Map.put(:namespace, Ambient.namespace(pid))
      #|> Map.put(:children, Ambient.get_from_ambient(pid, :ambients))
      {ambient_name, Ambient.Formatter.format(pid)}
    end)
    |> Enum.into(Map.new)
    Apex.ap nonlocal
  end
  def display_local_data() do
    Logger.info "Local Data:"
    {:ok, registrar} = Ambient.Registration.default()
    result = Ambient.Registration.get(registrar)
    |> Enum.map(fn {aname, registration}->
      pid = Map.get(registration,:pid)
      {aname,  Ambient.Formatter.format(pid)}
    end)
    |> Enum.into(%{})
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
