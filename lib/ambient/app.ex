defmodule Ambient.App do
  use Application
  require Logger

  def get_env(key, default) do
    Application.get_env(:ambientcalculus, key, default)
  end

  defmodule Soopervisor do
    @moduledoc """
    """
    use Supervisor

   def start_link(), do: Supervisor.start_link(__MODULE__, :ok)

   def init(:ok) do
     Logger.info Functions.red("Supervisor.init called")
     children = [
       #worker(Ambient, [:ambient1]),
       #worker(Ambient, [:ambient2]),
       #worker(Ambient.Discovery, []),
     ]
     supervise(children, strategy: :one_for_one)
   end
  end

  def start(_type, _args) do
    Universe.Supervisor.start_link()
  end
end
