defmodule PushHeartbeatMonitorTest do
  alias PushHeartbeatMonitorTest.HealthCheckMod
  use ExUnit.Case
  doctest PushHeartbeatMonitor

  import Mock

  test "able to send push monitor at minimal config" do
    with_mock Req, [
      get: fn "https://uptime.acme.org/api/push/abcdef?status=up", [{:headers, []}] ->
        {:ok, %Req.Response{status: 200}}
      end
    ] do
      assert {:ok, _pid} = PushHeartbeatMonitor.start_link(%{
        push_url: "https://uptime.acme.org/api/push/11111111-1111-1111-1111-111111111111",
        push_method: :get,
        push_success_arg: "status=up",
        push_failure_arg: "status=down"
      })
    end
  end

  test "able to send push monitor with bearer token and healthcheck func" do
    with_mock Req, [
      get: fn "https://gatus.acme.org/api/v1/endpoints/mygroup_myservice/external", [{:headers, [{"authorization", "Bearer 11111111-1111-1111-1111-111111111111"}]}] ->
        {:ok, %Req.Response{status: 200}}
      end
    ] do
      defmodule HealthCheckModA do
        def success(),
          do: :ok
      end

      assert {:ok, _pid} = PushHeartbeatMonitor.start_link(%{
        push_url: "https://gatus.acme.org/api/v1/endpoints/mygroup_myservice/external&success=true",
        push_method: :post,
        push_success_arg: "success=true",
        push_failure_arg: "success=false",
        push_token: "11111111-1111-1111-1111-111111111111",
        push_token_placement: :bearer,
        healthcheck_func: {HealthCheckModA, :success}
      })
    end
  end

  test "able to send push down status" do
    with_mock Req, [
      get: fn "https://uptime.acme.org/api/push/abcdef?status=down&msg=something went wrong", [{:headers, [{"x-token", "abcdef"}]}] ->
        {:ok, %Req.Response{status: 200}}
      end
    ] do
      defmodule HealthCheckModB do
        def fail(),
          do: {:error, "something went wrong"}
      end

      assert {:ok, _pid} = PushHeartbeatMonitor.start_link(%{
        push_url: "https://uptime.acme.org/api/push/11111111-1111-1111-1111-111111111111",
        push_method: :get,
        push_success_arg: "status=up",
        push_failure_arg: "status=down",
        push_message_param: "msg",
        push_token: "abcdef",
        healthcheck_func: {HealthCheckModB, :fail},
        push_token_placement: {:header, "x-token"}
      })
    end
  end
end
