require Logger
defmodule Ambient.Supervisor do
  use Supervisor
  def start_link(ambient_name) do
    Supervisor.start_link(
      __MODULE__,
      [ Atom.to_string(ambient_name) ]
      )
  end
  def init([ambient_name]) do
    Logger.info Functions.red "Starting Ambient.Supervisor for Ambient `#{ambient_name}`"
    programs = []
    children = programs ++ []
    opts = [strategy: :one_for_one]
    supervise(children, opts)
  end
end
