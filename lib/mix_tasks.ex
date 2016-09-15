defmodule Mix.Tasks.Observe do
  @moduledoc """
  """

  use Mix.Task

  @doc """
  """
  def run(anything) do
    Mix.Tasks.App.Start.run([])
    main(anything)
  end

  @doc """
  """
  def main([]) do
    :observer.start()
  end

end
