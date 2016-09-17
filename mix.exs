defmodule AmbientCalculus.Mixfile do
  use Mix.Project

  def project do
    [app: :ambientcalculus,
     version: "0.1.0",
     elixir: "~> 1.3",
     default_task: "app.start",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [
       tool: Coverex.Task,
       console_log: true],
      deps: deps(Mix.env)]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application() do
    [
      mod: {Ambient.App, [Node.self]},
      applications: [
      :logger,
      ],
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps(), do: deps(Mix.env)
  defp deps(env) do
    base = [
      { :ex_slp,
        git: "https://github.com/icanhazbroccoli/ex_slp_tk.git",
        tag: "76a2f" },

      #
      {:apex, "~>0.5.2"},

      # a linter for elixir code
      {:dogma, "~> 0.1", only: :dev},

      # repeatedly reruns test cases
      {:mix_test_watch, "~> 0.2", only: :dev},

      # NB: 0.1.4 is available on github but not hex currently
      {:mock, "~> 0.1.4", git: "https://github.com/jjh42/mock.git"},

      # a static analysis tool
      {:dialyxir, "~> 0.3", only: [:dev]},

      # coverage tool for tests
      # https://github.com/alfert/coverex
      {:coverex, "~> 1.4.9", only: :test},
    ]
    case env do
      _ -> base
    end
  end
end
