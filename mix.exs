defmodule MaelstromTutorial.MixProject do
  use Mix.Project

  @main_module_mapping %{
    "echo" => MaelstromTutorial.EchoServer.Server,
    "broadcast" => MaelstromTutorial.BroadcastServer.Server,
    "g_set" => MaelstromTutorial.GSetServer.Server
  }

  def project do
    [
      app: :maelstrom_tutorial,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript_config()
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:poison, "~> 6.0"}
    ]
  end

  defp escript_config do
    module_name = System.get_env("MODULE", "echo")

    main_module =
      Map.get(@main_module_mapping, module_name) ||
        raise("Could not find main_module matching '#{module_name}'")

    [
      main_module: main_module,
      name: module_name,
      embed_elixir: true,
      app: nil
    ]
  end
end
