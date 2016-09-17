require Logger
defmodule Ambient.Supervisor do
  use Supervisor
  def start_link(ambient_name) do
    Supervisor.start_link(
      __MODULE__,
      [ Functions.to_atom(ambient_name) ]
      )
  end
  def init([ambient_name]) when is_atom(ambient_name) do
    msg = Functions.red "Ambient[#{ambient_name}].Supervisor: "
    Logger.info(msg <> "starting")
    programs = []
    children = programs ++ []
    opts = [strategy: :one_for_all]
    supervise(children, opts)
  end
end
