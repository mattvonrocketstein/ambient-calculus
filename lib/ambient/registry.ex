require Logger
import Apex.AwesomeDef
defmodule Ambient.Registration do
  @doc """
  """
  @name __MODULE__
  def start_link() do
    registry = %{}
    msg = Functions.red("Ambient.Registration: ")
    result = if( Process.whereis(@name)!=nil) do
      {:error, :already_started}
    else
      {:ok, pid} = Agent.start_link(
        fn -> Map.new()  end,
        name: @name)
    end
    if {:ok, pid} = result do
      Logger.info msg <> "started"
    end
    result
  end

  @doc """
  """
  def myself, do: Process.whereis(@name)

  def sync_globals() do
    registrations = get()
    Enum.map(registrations, fn {k,v} ->
      Logger.info "  sync name: #{inspect k}"
      :global.register_name(k, Map.get(v, :pid))
    end)
  end

  @doc """
  """
  def get_ambient(name) when is_atom(name) do
    Map.get(get(name), :pid)
  end
  def get_ambient(name) when is_bitstring(name) do
    name = String.to_atom(name)
    :global.whereis_name(name)#get_ambient(name) || 
  end

  @doc """
  """
  def get(), do: Agent.get(myself(), fn registry -> registry end)
  def get(name) do
    Map.get( get(), name)
  end

  @doc """
  """
  def register(name, ambient) when Kernel.is_pid(ambient) do
    {:ok, put(name, :pid, ambient)}
  end

  @doc """
  """
  def put(name, key, val) do
    Agent.update(
      myself(),
      fn registry ->
        Map.put(
          registry,
          name,
          Map.put(
            Map.get(registry, name) || %{},
            key, val))
      end)
  end
end
