defmodule Ambient.Formatter do
  defp format_children(ambient) do
    Ambient.children(ambient)
    |> Enum.map(fn {name,pid} ->
        {name, Ambient.Formatter.format(pid)} end)
    |> Enum.into(Map.new)
  end
  def format(ambient) do
    case Ambient.healthy?(ambient) do
      false ->
        %{
          unhealthy: true,
          reason: Ambient.health_issues(ambient)
        }
      true ->
        %{
          children: format_children(ambient),
          namespace: Ambient.namespace(ambient),
          node: Ambient.node(ambient)
        }

    end
  end
end
