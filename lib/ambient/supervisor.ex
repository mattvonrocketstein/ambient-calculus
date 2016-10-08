require Logger
defmodule ProgSpace do
  use Supervisor

  def start_link(ambient_name) do
    Task.Supervisor.start_link(
      name: :"#{to_string(ambient_name)}-progman")
  end

  def create_for(ambient) do
    ambient_name = Ambient.name(ambient)
    msg = "creating program-space supervisor for ambient #{ambient_name}"
    Logger.info msg
    {:ok, _sup_pid} = start_link(ambient_name)
  end

end
