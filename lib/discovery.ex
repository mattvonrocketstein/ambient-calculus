require Logger

defmodule Discovery do
  def discover() do
    nodes = ExSlp.Service.discover()
    result = Enum.filter(
      nodes,
      fn node ->
        case ExSlp.Service.connect(node) do
          # see http://elixir-lang.org/docs/stable/elixir/Node.html#connect/1
          :ignored ->
            # Node.connect() ignored a down host
            Logger.info("Connection to #{inspect node} ignored")
          false ->
            # Connection failed
            Logger.info("Connection to #{inspect node} failed")
            nil
          true ->
            # Connection successful (but not necessarily new)
            node
        end
      end)
      msg = Functions.red("SLP Discovery: ")
      #Logger.info msg <> "#{inspect result}"
  end
  def register() do
    {:ok, result} = ExSlp.Service.register()
    Logger.info Functions.red("Ran registration task:")<>" ok"
  end
end
