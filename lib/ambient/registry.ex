require Logger
import Apex.AwesomeDef
defmodule Ambient.Registration do
  @doc """
  """
  def start_link() do
    registry = %{}
    result = if( Process.whereis(__MODULE__)!=nil) do
      {:error, :already_started}
    else
      {:ok, pid} = Agent.start_link(
        fn -> Map.new()  end,
        name: __MODULE__)
    end
    if {:ok, pid} = result do
      Logger.info Functions.red("Ambient.Registration: ")<> "started as #{inspect pid}"
    end
    result
  end

  def myself, do: Process.whereis(__MODULE__)

  def get(), do: Agent.get(myself(), fn registry -> registry end)
  def get(name) do
    Agent.get(
      myself(),
      fn registry ->
        Map.get(registry, name)
      end)
  end

  adef show_status() do
    get()
  end

  def register(name, ambient) when Kernel.is_pid(ambient) do
    Agent.get_and_update(
      myself(),
      fn registry ->
        registration = %{}
        |> Map.put(:pid, ambient)
        Map.put(registry, name, registration)
      end)
  end

  def put(name, key, val) do
    Agent.get_and_update(
      myself(),
      fn registry ->
        registration = Map.get(registry, name)
        registration = registration
        |> Map.put(key, val)
        Map.put(registry, name, registration)
      end)
  end
end
