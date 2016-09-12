# ambient-calculus
## About

[ex_slp](https://github.com/icanhazbroccoli/ex_slp_tk)
[discovery with consul](https://github.com/undeadlabs/discovery)

## Prerequisites

Installing elixir: [see instructions here](http://elixir-lang.org/install.html#unix-and-unix-like)

Installing OpenSLP:

    sudo apt-get install slpd libslp-dev libslp1 slptool
    sudo /etc/init.d/slpd start

## Installation

### As a library

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `ambient-calculus` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ambient-calculus, "~> 0.1.0"}]
    end
    ```

  2. Ensure `ambient-calculus` is started before your application:

    ```elixir
    def application do
      [applications: [:ambientcalculus]]
    end
    ```

### For developers

**Clone this repository and enter source root**

    $ git clone git@github.com:mattvonrocketstein/ambientcalculus.git ambient-calculus
    $ cd ambient-calculus

**Install Elixir project dependencies**

    $ mix deps.get

## Mix commands

### Run tests

    $ mix test --cover

### Creating a commandline script

    $ mix escript.build
    $ ./ambientcalculus [args]

### Run linter

    $ mix dogma

### Run static analysis

The first time you have to build the [persistent lookup table](https://github.com/jeremyjh/dialyxir#plt), which takes a while.

    $ mix dialyzer.plt

Thereafter, just run

    $ mix dialyzer

## Installing project pre-commit hooks

    $ cd ambient-calculus
    $ sudo pip install pre-commit
    $ pre-commit install
