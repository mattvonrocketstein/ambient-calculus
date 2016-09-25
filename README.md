# ambient-calculus

## About

See a full description of this project [here](https://mattvonrocketstein.github.io/heredoc/elixir-ambient-calculus.html)

## Prerequisites

### Installing Elixir

[See instructions here](http://elixir-lang.org/install.html#unix-and-unix-like)

### Installing OpenSLP

This app uses [ex_slp](https://github.com/icanhazbroccoli/ex_slp_tk) for node discovery and clustering.

There's an ubuntu package for `slpd` and `slp-tool`, and there's also a [docker image](https://hub.docker.com/r/vcrhonek/openslp/) that has both.  To install and verify installation for debian based systems use something like what you see below.

    :::bash
    $ sudo apt-get install slpd slp-tool
    $ sudo /etc/init.d/slpd restart
    $ slptool --version

You'll want to install the command line tool regardless, but it's possible to use the daemon via docker:

    :::bash
    # Run slpd via docker and background it
    $ docker run -d -p 427:427/tcp -p 427:427/udp  --name openslp vcrhonek/openslp

## Installation

**Clone this repository and enter source root**

    $ git clone git@github.com:mattvonrocketstein/ambientcalculus.git ambient-calculus
    $ cd ambient-calculus

**Install Elixir project dependencies**

    $ mix deps.get
    $ mix compile


## For developers

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

### Installing project pre-commit hooks

    $ cd ambient-calculus
    $ sudo pip install pre-commit
    $ pre-commit install
