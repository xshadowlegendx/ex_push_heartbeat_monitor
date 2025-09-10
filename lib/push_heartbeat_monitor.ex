defmodule PushHeartbeatMonitor do
  @moduledoc """
  Documentation for `PushHeartbeatMonitor`.
  """

  use GenServer

  require Logger

  @typedoc """
  * `push_url` - url to push to monitor service, eg: https://gatus.acme.org/api/v1/endpoints/mygroup_myservice/external
  * `push_success_arg` - success query param to set on the monitor service, eg: `success=true` or `status=up`
  * `push_failure_arg` - failure query param to set on the monitor service, eg: `success=false` or `status=down`
  * `push_token` - token to authenticate to the monitor service, eg: `11111111-1111-1111-1111-111111111111`
  * `push_token_placement` - where to put token for authentication, eg: `:bearer` or `{:header, "x-api-key"}`
  * `push_message_param` - message to set on the monitor service  eg: `error` or `msg`
  * `push_method` - method to send the push request, eg: `:get`
  * `push_interval_in_seconds` - push interval in seconds, eg: `20`
  * `healthcheck_function` - module function for custom health check logic, return `:ok` or `{:error, "message"}`, eg: `{MyHealthCheckModule, :check_all}`
  """
  @type config :: %{
    :push_url => String.t(),
    :push_success_arg => String.t(),
    :push_failure_arg => String.t(),
    optional(:push_token) => String.t(),
    optional(:push_token_placement) => :bearer | {:header, String.t()},
    optional(:push_message_param) => String.t(),
    optional(:push_method) => :get | :post,
    optional(:push_interval_in_seconds) => non_neg_integer(),
    optional(:healthcheck_function) => nil | {module(), atom()}
  }

  @default_config %{
    push_message_param: "msg",
    push_method: :post,
    push_interval_in_seconds: 20,
    healthcheck_function: nil
  }

  @spec start_link(opts :: config()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    config = Map.merge(@default_config, opts)

    config = Map.put(config, :push_interval, config.push_interval_in_seconds * 1000)

    {:ok, %{config: config}, {:continue, :push_monitor}}
  end

  @impl true
  def handle_continue(:push_monitor, state) do
    Logger.info("push heartbeat monitor started")

    :ok = Process.send(self(), :push_monitor, [])

    {:noreply, state}
  end

  @impl true
  def handle_info(:push_monitor, state) do
    _ref = Process.send_after(self(), :push_monitor, state.config.push_interval)

    case do_push_heartbeat(state.config) do
      {:ok, %Req.Response{status: status}} when status in [200, 204] ->
        Logger.debug("push heartbeat sent")

      {:ok, %Req.Response{status: status, body: resp}} ->
        Logger.warning("failed to push heartbeat - status:#{status}, resp:#{heartbeat_response_to_string(resp)}")

      {:error, exception} ->
        Logger.error("error pushing heartbeat - #{Exception.message(exception)}")
    end

    {:noreply, state}
  end

  defp heartbeat_response_to_string(resp) when is_map(resp) or is_list(resp),
    do: :json.encode(resp)

  defp heartbeat_response_to_string(resp) when is_binary(resp),
    do: resp

  defp do_push_heartbeat(%{healthcheck_func: {mod, func}} = config) do
    healthcheck = apply(mod, func, [])

    push_url = construct_push_url_with_params(config, healthcheck)

    apply(Req, config.push_method, [push_url, [headers: set_auth_header(config)]])
  end

  defp do_push_heartbeat(config) do
    push_url = construct_push_url_with_params(config, :ok)

    apply(Req, config.push_method, [push_url, [headers: set_auth_header(config)]])
  end

  defp construct_push_url_with_params(config, :ok),
    do: "#{config.push_url}?#{config.push_success_arg}"

  defp construct_push_url_with_params(config, {:error, message}),
    do: "#{config.push_url}?#{config.push_failure_arg}&#{config.push_message_param}=#{message}"

  defp set_auth_header(%{push_token: push_token, push_token_placement: :bearer}),
    do: [{"authorization", "Bearer #{push_token}"}]

  defp set_auth_header(%{push_token: push_token, push_token_placement: {:header, header}}),
    do: [{header, push_token}]

  defp set_auth_header(_config),
    do: []
end
