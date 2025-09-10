defmodule PushHeartbeatMonitor.MixProject do
  use Mix.Project

  def project do
    [
      app: :push_heartbeat_monitor,
      version: "0.1.1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description(),
      test_coverage: [tool: ExCoveralls],
      name: "PushHeartbeatMonitor",
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ]
    ]
  end

  defp description() do
    "A process to periodically send heartbeat to monitoring service"
  end

  defp package() do
    [
      name: "push_heartbeat_monitor",
      licenses: ["Apache-2.0"],
      links: %{"Github" => "https://github.com/xshadowlegendx/ex_push_heartbeat_monitor.git"}
    ]
  end

  defp docs() do
    [
      main: "readme",
      source_url: "https://github.com/xshadowlegendx/push_heartbeat_monitor",
      extras: [
        "README.md"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5.0"},
      {:mock, "~> 0.3.0", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end
end
