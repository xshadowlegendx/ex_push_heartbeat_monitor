defmodule PushHeartbeatMonitorTest do
  use ExUnit.Case
  doctest PushHeartbeatMonitor

  import Mock

  test "able to start and send push monitor at minimal config" do
    assert {:ok, state, {:continue, cont = :push_monitor}} = PushHeartbeatMonitor.init(%{
      push_url: "https://uptime.acme.org/api/push/11111111-1111-1111-1111-111111111111",
      push_method: :get,
      push_success_arg: "status=up",
      push_failure_arg: "status=down"
    })

    with_mock Req, [
      get: fn _url, [{:headers, []}] ->
        {:ok, %Req.Response{status: 200}}
      end
    ] do
      assert {:noreply, _state} = PushHeartbeatMonitor.handle_continue(cont, state)
    end
  end

  test "able to handle error without crashing" do
    with_mock Req, [
      get: fn
        "error-json:" <> _url, [{:headers, []}] ->
          {:ok, %Req.Response{status: 500, body: "something went wrong"}}

        "error-list:" <> _url, [{:headers, []}] ->
          {:ok, %Req.Response{status: 500, body: [%{"detail" => nil, "error" => "something went wrong"}]}}

        "error:" <> _url, [{:headers, []}] ->
          {:error, %Req.TooManyRedirectsError{}}
      end
    ] do
      assert {:noreply, _state} = PushHeartbeatMonitor.handle_info(
        :push_monitor,
        %{
          config: %{
            push_url: "error-json:https://uptime.acme.org/api/push/11111111-1111-1111-1111-111111111111",
            push_interval: 32_000,
            push_method: :get,
            push_success_arg: "status=up",
            push_failure_arg: "status=down"
          }
        }
      )

      assert {:noreply, _state} = PushHeartbeatMonitor.handle_info(
        :push_monitor,
        %{
          config: %{
            push_url: "error-list:https://uptime.acme.org/api/push/11111111-1111-1111-1111-111111111111",
            push_interval: 32_000,
            push_method: :get,
            push_success_arg: "status=up",
            push_failure_arg: "status=down"
          }
        }
      )

      assert {:noreply, _state} = PushHeartbeatMonitor.handle_info(
        :push_monitor,
        %{
          config: %{
            push_url: "error:https://uptime.acme.org/api/push/11111111-1111-1111-1111-111111111111",
            push_interval: 32_000,
            push_method: :get,
            push_success_arg: "status=up",
            push_failure_arg: "status=down"
          }
        }
      )
    end
  end

  test "able to send push monitor with bearer token and healthcheck func" do
    with_mock Req, [
      post: fn "https://gatus.acme.org/api/v1/endpoints/mygroup_myservice/external?success=true", [{:headers, [{"authorization", "Bearer 11111111-1111-1111-1111-111111111111"}]}] ->
        {:ok, %Req.Response{status: 200}}
      end
    ] do
      defmodule HealthCheckModA do
        def success(),
          do: :ok
      end

      assert {:noreply, _state} =
        PushHeartbeatMonitor.handle_info(
          :push_monitor,
          %{
            config: %{
              push_url: "https://gatus.acme.org/api/v1/endpoints/mygroup_myservice/external",
              push_interval: 32_000,
              push_method: :post,
              push_success_arg: "success=true",
              push_failure_arg: "success=false",
              push_token: "11111111-1111-1111-1111-111111111111",
              push_token_placement: :bearer,
              healthcheck_func: {HealthCheckModA, :success}
            }
          }
        )
    end
  end

  test "able to send push down status" do
    with_mock Req, [
      get: fn "https://uptime.acme.org/api/push/11111111-1111-1111-1111-111111111111?status=down&msg=something went wrong", [{:headers, [{"x-token", "abcdef"}]}] ->
        {:ok, %Req.Response{status: 200}}
      end
    ] do
      defmodule HealthCheckModB do
        def fail(),
          do: {:error, "something went wrong"}
      end

      assert {:noreply, _state} =
        PushHeartbeatMonitor.handle_info(
          :push_monitor,
          %{
            config: %{
              push_interval: 32_000,
              push_url: "https://uptime.acme.org/api/push/11111111-1111-1111-1111-111111111111",
              push_method: :get,
              push_success_arg: "status=up",
              push_failure_arg: "status=down",
              push_message_param: "msg",
              push_token: "abcdef",
              healthcheck_func: {HealthCheckModB, :fail},
              push_token_placement: {:header, "x-token"}
            }
          }
        )
    end
  end
end
