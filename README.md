# PushHeartbeatMonitor

A process to periodically send heartbeat to monitoring service

## Installation

If [available in Hex](hexdocs.pm/push_heartbeat_monitor/), the package can be installed
by adding `push_heartbeat_monitor` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:push_heartbeat_monitor, "~> 0.1.0"}
  ]
end
```

## Example Usage

```bash
# assuming u have docker and elixir phoenix installed
# start a uptime monitor service or you can choose any compatible public offer
cat <<EOF> /tmp/gatus-config.yml
endpoints:
  - name: httpbin
    enabled: false
    url: https://httpbin.org/get
    conditions:
      - '[STATUS] == 200'

external-endpoints:
  - name: myapp
    group: core
    token: potato
    heartbeat:
      interval: 32s
EOF

docker run -p 8880:8080 -v /tmp/gatus-config.yml:/config/config.yaml twinproduction/gatus
```

```elixir
# add the dependency in your elixir project and
# setup config as such in `config/config.exs`
config :your_app_name, :push_heartbeat, %{
  push_url: "http://localhost:8880/api/v1/endpoints/core_myapp/external",
  push_method: :post,
  push_success_arg: "success=true",
  push_failure_arg: "success=false",
  push_token: "potato",
  push_token_placement: :bearer
}

# and start it sth like this if using a supervisor
children = [{PushHeartbeatMonitor, Application.get_env(:your_app_name, :push_heartbeat)}]

opts = [strategy: :one_for_one, name: MyApp.Supervisor]
Supervisor.start_link(children, opts)
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/push_heartbeat_monitor>.
