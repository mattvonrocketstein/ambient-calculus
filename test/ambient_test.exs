Process.flag(:trap_exit, true)
defmodule Ambient.Test do
  use ExUnit.Case, async: false

  # "setup_all" is called once to setup the case before any test is run
  setup_all do
    IO.puts "Starting AmbientTest"
    # No metadata
    :ok
  end

  # "setup" is called before each test is run
  setup do
    # important, otherwise Ambient.open() will fail tests because it calls Agent.stop()
    Process.flag(:trap_exit, true)
    on_exit fn ->
      #IO.puts "This is invoked once the test is done
      :noop
    end

    # Returns extra metadata to be merged into context
    [hello: "world"]
  end

  # Same as "setup", but receives the context
  # for the current test
  setup context do
    msg = IO.ANSI.red()<>"Testing: "
    test_bits = String.split(Atom.to_string(context[:test]))
    test_name = test_bits
    |> Enum.slice(1, Enum.count(test_bits))
    |> Enum.join(" ")
    msg = msg <> IO.ANSI.yellow() <> test_name <> IO.ANSI.reset()
    msg = msg<>"\n"
    IO.puts msg
    :ok
  end

  # Setups can also invoke a local or imported function
  setup :invoke_local_or_imported_function

  test "demonstrate context", context do
    assert context[:hello] == "world"
  end

  defp invoke_local_or_imported_function(_context) do
    [from_named_setup: true]
  end

  test "ambient initialization" do
    {:ok, ambient1} = Ambient.start_link(:ambient1)
    namespace = Ambient.get(ambient1)
    assert %{:parent => _parent} = namespace
    IO.puts("#{inspect namespace}")
  end

  test "ambient data persistence" do
    {:ok, ambient1} = Ambient.start_link(:ambient1)
    Ambient.push(ambient1, :foo, :bar)
    namespace = Ambient.get(ambient1)
    assert namespace[:foo] == :bar
    assert Ambient.pop(ambient1, :foo)==:bar
    namespace = Ambient.get(ambient1)
    assert not Map.has_key?(namespace, :foo)
  end

  test "toplevel ambient is singleton" do
    Ambient.TopLevel.get()==Ambient.TopLevel.get()
  end

  test "nested ambients" do
    {:ok, ambient1} = Ambient.start_link(:ambient1)
    {:ok, ambient2} = Ambient.start_link(:ambient2)
    Ambient.push(ambient1, :ambient2, ambient2)
  end
  test "default parent is toplevel" do
    {:ok, ambient1} = Ambient.start_link(:ambient1)
    assert Ambient.get_parent(ambient1) == Ambient.TopLevel.get()
  end
  test "toplevel exit" do
    toplevel = Ambient.TopLevel.get()
    assert nil == Ambient.exit(toplevel)
  end
  test "toplevel parent is toplevel" do
    toplevel = Ambient.TopLevel.get()
    assert toplevel==Ambient.parent(toplevel)
  end

  test "entry/exit capability" do
    {:ok, ambient1} = Ambient.start_link(:ambient1)
    {:ok, ambient2} = Ambient.start_link(:ambient2)
    ambient2 |> Ambient.enter(ambient1)
    assert Ambient.parent(ambient2) == ambient1
    ambient2 |> Ambient.exit()
    assert Ambient.parent(ambient2) == Ambient.TopLevel.get()
  end

  test "open capability" do
    {:ok, ambient1} = Ambient.start_link(:ambient1)
    {:ok, ambient2} = Ambient.start_link(:ambient2)
    ambient1|>Ambient.push(:foo,:bar)
    ambient1|>Ambient.enter(ambient2)
    assert nil==Ambient.get(ambient2, :foo)
    Ambient.open(ambient1)
    assert :bar==Ambient.get(ambient2, :foo)
  end

  test "entry capability" do
    {:ok, ambient1} = Ambient.start_link(:ambient1)
    {:ok, ambient2} = Ambient.start_link(:ambient2)
    ambient2 |> Ambient.enter(ambient1)
    assert Ambient.parent(ambient2) == ambient1
    assert ambient2 == Ambient.get(ambient1, Ambient.name(ambient2))
  end

  test "ambient parent assignment" do
    {:ok, ambient1} = Ambient.start_link(:ambient1)
    {:ok, ambient2} = Ambient.start_link(:ambient2, ambient1)
    assert Ambient.get_parent(ambient2) == ambient1
  end
end
