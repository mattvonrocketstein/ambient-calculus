defmodule AmbientOTP.Test do
  use ExUnit.Case, async: true

  # "setup_all" is called once to setup the case before any test is run
  setup_all do
    IO.puts "Starting AmbientOTP Test"
    :ok # No metadata
  end

  test "basic start_link" do
    {:ok, _pid} = Ambient.start_link(:whatever)
  end
end

defmodule AmbientBase.Test do
  use ExUnit.Case, async: true

  # "setup_all" is called once to setup the case before any test is run
  setup_all do
    IO.puts Functions.red "Starting test-class: AmbientBaseTest"
    :ok # No metadata
  end


  setup do
    # called before each test is run
    # important, otherwise Ambient.open() will fail
    # tests because it calls Agent.stop()
    #Process.flag(:trap_exit, true)
    #on_exit fn ->
      #IO.puts "This is invoked once the test is done
    #  :noop
    #end
    # Returns extra metadata to be merged into context
    {:ok,ambient1} = Ambient.start_link(:ambient1)
    {:ok, ambient2} = Ambient.start_link(:ambient2)
    [
      ambient1: ambient1,
      ambient2: ambient2,
      program: fn _x ->
        Display.write("test program!")
        :timer.sleep(3000)
      end,
    ]
  end

  # Same as "setup", but receives the context
  # for the current test
  setup context do
    msg = IO.ANSI.red() <> "\nTesting: "<> IO.ANSI.reset()
    test_bits = String.split(Atom.to_string(context[:test]))
    test_name = test_bits
    |> Enum.slice(1, Enum.count(test_bits))
    |> Enum.join(" ")
    msg = msg <> IO.ANSI.yellow() <> test_name <> IO.ANSI.reset()
    msg = msg#<>"\n"
    IO.puts msg
    :timer.sleep(1000)
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

  test "ambient namespace data persistence", ctx do
    ambient1 = ctx.ambient1
    Ambient.put(ambient1, :foo, :bar)
    namespace = Ambient.namespace(ambient1)
    assert namespace[:foo] == :bar
    {:bar, updated_namespace} = Ambient.pop(
      ambient1, :foo)
    assert updated_namespace == Ambient.get(ambient1)
    assert not Map.has_key?(updated_namespace, :foo)
  end

  test "ambient siblings", ctx do
    ambient1 = ctx.ambient1
    ambient2 = ctx.ambient2
    sibling = Ambient.Topology.siblings(ambient1)
    assert ambient2 in Map.values(sibling)
  end

  test "default parent is toplevel", %{ambient1: ambient1} do
    assert Ambient.parent(ambient1) == nil
  end
  test "topology: clustering", _ctx do
    assert 0==Ambient.Topology.nonlocal_ambients()
    |> Enum.count
  end
  test "topology: locality", %{ambient1: ambient1} do
    assert not Ambient.Topology.remote?(ambient1)
    assert Ambient.Topology.local?(ambient1)
  end
  test "topology: parent assignment", %{ambient1: ambient1, ambient2: ambient2} do
    assert not Ambient.has_child?(ambient1, ambient2)
    assert Ambient.parent(ambient2) == nil
    Ambient.reset_parent(ambient2, ambient1)
    assert Ambient.parent(ambient2) == ambient1
    assert Ambient.has_child?(ambient1, ambient2)
  end

  test "ambient is a sibling of itself", %{ambient1: ambient1} do
    assert Ambient.Topology.siblings(ambient1)
    |> Map.keys
    |> Enum.member?(:ambient1)
  end

  test "program manager running", %{ambient1: ambient1} do
     assert Process.alive?(Ambient.progman(ambient1))
  end

  test "progspace persistence", %{ambient1: ambient1, program: prog} do
    assert is_function(prog, 1)
    program_label=:test_program
    Ambient.add_program(ambient1, program_label, prog)
    assert ambient1
    |> Ambient.progspace()
    |> Map.keys
    |> Enum.member?(program_label)
    assert Ambient.Algebra.count_progs(ambient1) == 1
    assert Ambient.Algebra.count_running_progs(ambient1) == 0
  end

  test "progman runs programs", %{ambient1: ambient1, program: prog} do
    program_label = :test_program
    Ambient.add_program(ambient1, program_label, prog)
    {:ok, pid} = Ambient.start_program(ambient1, program_label)
    assert Process.alive?(pid)
    assert Ambient.Algebra.count_running_progs(ambient1) == 1
  end

  test "parent/child relationship is not sibling", %{ambient1: ambient1, ambient2: ambient2} do
    Ambient.reset_parent(ambient2, ambient1)
    assert Ambient.parent(ambient2) == ambient1
    siblings = Ambient.Topology.siblings(ambient1)
    assert not Enum.member?(Map.keys(siblings), :ambient2)
    siblings = Ambient.Topology.siblings(ambient2)
    assert not Enum.member?(Map.keys(siblings), :ambient1)
  end
end
