require Logger
import Apex.AwesomeDef
defmodule Ambient.Registration do
  @doc """
  """
  @name __MODULE__
  def start_link() do
    registry = %{}
    msg = Functions.red("Ambient.Registration: ")
    result = if( Process.whereis(__MODULE__)!=nil) do
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

  @doc """
  """
  def get(), do: Agent.get(myself(), fn registry -> registry end)
  def get(name) do
    Agent.get(
      myself(),
      fn registry ->
        Map.get(registry, name)
      end) || :global.whereis_name(name)
  end

  def show_status(x) do
    header = ""#step #{Functions.red inspect x} for "
    header= header <> "Node[#{Functions.red Atom.to_string(Node.self())}]"
    IO.puts header
    #IO.puts "this-node: #{Atom.to_string(Node.self())}"
    IO.puts "AmbientCluster: "<>Enum.join(Node.list(),", ")
    IO.puts "AmbientRegistry:\n"
    Apex.ap get()
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
