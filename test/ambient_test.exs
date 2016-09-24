defmodule AmbientOTP.Test do
  use ExUnit.Case, async: true

  # "setup_all" is called once to setup the case before any test is run
  setup_all do
    IO.puts "Starting AmbientOTP Test"
    :ok # No metadata
  end

  test "basic start_link" do
    {:ok, pid} = Ambient.start_link(:whatever)
  end
end
defmodule AmbientBase.Test do
  use ExUnit.Case, async: true

  # "setup_all" is called once to setup the case before any test is run
  setup_all do
    IO.puts "Starting AmbientBaseTest"
    :ok # No metadata
  end


  setup do # called before each test is run
    # important, otherwise Ambient.open() will fail
    # tests because it calls Agent.stop()
    #Process.flag(:trap_exit, true)
    #on_exit fn ->
      #IO.puts "This is invoked once the test is done
    #  :noop
    #end
    # Returns extra metadata to be merged into context
    ambient1 = Ambient.get_or_start(:ambient1)
    ambient2 = Ambient.get_or_start(:ambient2)
    [
      ambient1: ambient1,
      ambient2: ambient2
    ]
  end

  # Same as "setup", but receives the context
  # for the current test
  setup context do
    msg = IO.ANSI.red()<>"\nTesting: "
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

  defp invoke_local_or_imported_function(_context) do
    [from_named_setup: true]
  end

  test "ambient initialization",ctx do
    ambient1 = ctx.ambient1
    namespace = Ambient.get(ambient1)
    assert %{:parent => _parent} = namespace
    IO.puts("#{inspect namespace}")
  end

  test "ambient data persistence",ctx do
    ambient1 = ctx.ambient1
    Ambient.push(ambient1, :foo, :bar)
    namespace = Ambient.namespace(ambient1)
    assert namespace[:foo] == :bar
    {:bar, updated_namespace} = Ambient.pop(
      ambient1, :foo)
    assert updated_namespace == Ambient.get(ambient1)
    assert not Map.has_key?(updated_namespace, :foo)
  end

  test "nested ambients",ctx do
    ambient1 = ctx.ambient1
    ambient2 = ctx.ambient2
    Ambient.push(ambient1, :ambient2, ambient2)
  end

  test "default parent is toplevel",%{ambient1: ambient1} do
    assert Ambient.parent(ambient1) == nil
  end

  test "parent assignment", %{ambient1: ambient1, ambient2: ambient2} do
    Ambient.reset_parent(ambient2, ambient1)
    assert Ambient.parent(ambient2) == ambient1
  end
end
