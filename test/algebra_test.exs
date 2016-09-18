defmodule Algebra.Test do
  #use ExUnit.Case, async: false
  use ExUnit.Case, async: true

  # "setup_all" is called once to setup the case before any test is run
  setup_all do
    IO.puts "Starting AmbientTest"
    # No metadata
    :ok
  end

  # "setup" is called before each test is run
  setup do
    # important, otherwise Ambient.open() will fail
    # tests because it calls Agent.stop()
    Process.flag(:trap_exit, true)
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

  defp invoke_local_or_imported_function(_context) do
    [from_named_setup: true]
  end

  test "exit capability", %{ambient1: ambient1, ambient2: ambient2} do
    #ambient2 |> Ambient.Algebra.enter(ambient1)
    #assert Ambient.parent(ambient2) == ambient1
    #ambient2 |> Ambient.Algebra.exit()
    #assert Ambient.parent(ambient2) != ambient1
  end

  test "open capability", %{ambient1: ambient1, ambient2: ambient2} do
    ambient1|>Ambient.put(:foo, :bar)
    ambient1|>Ambient.Algebra.enter(ambient2)
    assert nil==Ambient.namespace(ambient2)[:foo]
    Ambient.Algebra.open(ambient1)
    assert :bar==Ambient.namespace(ambient2)[:foo]
  end

  test "entry capability", %{ambient1: ambient1, ambient2: ambient2} do
    ambient2 |> Ambient.Algebra.enter(ambient1)
    assert Ambient.parent(ambient2) == ambient1
    assert ambient2 in Map.values(Ambient.children(ambient1))
    assert Ambient.has_child?(ambient1, ambient2)
  end

end
