defmodule Ambient.TopLevel do
  def get_name() do
    [server_name, _host_name] = String.split(Atom.to_string(Node.self()), "@")
    String.to_atom(server_name)
  end
  def get() do
    pid = Process.whereis(get_name())
    pid = Kernel.is_pid(pid)
    case pid do
        nil ->
          {:ok, pid} = Ambient.TopLevel.start_link()
          pid
        _ ->
          pid
    end
  end
  def start_link() do
    server_name = get_name()
    IO.puts("STARTING TOPLEVEL: #{server_name}")
    Ambient.start_link(server_name, :toplevel)
  end
end
