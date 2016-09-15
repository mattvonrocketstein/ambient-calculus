require Logger

defmodule Functions do
  def noop(), do: :NOOP
  def red(msg), do: IO.ANSI.red()<>msg<>IO.ANSI.reset()
  def write_red(msg), do: Logger.info(Functions.red(msg))
end
