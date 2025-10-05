defmodule ApifyClientTest.CostTracker do
  @moduledoc """
  Helper module for tracking API costs during integration tests.

  This module provides utilities for measuring compute unit usage,
  data transfer, and storage costs when recording ReqOrd cassettes.
  """

  alias ApifyClient.Resources.User

  @doc """
  Gets current usage statistics for cost tracking.
  """
  def get_usage(client) do
    client
    |> ApifyClient.user("me")
    |> User.monthly_usage()
  end

  @doc """
  Calculates the cost difference between two usage reports.
  """
  def calculate_cost_diff(initial_usage, final_usage) do
    %{
      compute: calculate_metric_diff(initial_usage, final_usage, "compute"),
      data_transfer: calculate_metric_diff(initial_usage, final_usage, "dataTransfer"),
      storage: calculate_metric_diff(initial_usage, final_usage, "storage")
    }
  end

  @doc """
  Formats and displays cost information if in record mode.
  """
  def report_costs(test_name, initial_usage, final_usage, options \\ []) do
    record_mode = System.get_env("REQORD") != nil

    if record_mode do
      cost_diff = calculate_cost_diff(initial_usage, final_usage)

      IO.puts("\n💰 COST REPORT: #{test_name}")
      IO.puts("=" |> String.duplicate(50))

      # Compute units
      if cost_diff.compute.used > 0 do
        IO.puts("🖥️  Compute Units:")
        IO.puts("   Used: #{cost_diff.compute.used}")
        IO.puts("   Estimated cost: $#{estimate_compute_cost(cost_diff.compute.used)} USD")
      else
        IO.puts("🖥️  Compute Units: <0.01 (may not be updated yet)")
      end

      # Data transfer
      if cost_diff.data_transfer.used > 0 do
        IO.puts("📡 Data Transfer:")
        IO.puts("   Used: #{format_bytes(cost_diff.data_transfer.used)}")

        IO.puts(
          "   Estimated cost: $#{estimate_data_transfer_cost(cost_diff.data_transfer.used)} USD"
        )
      end

      # Storage
      if cost_diff.storage.used > 0 do
        IO.puts("💾 Storage:")
        IO.puts("   Used: #{format_bytes(cost_diff.storage.used)}")
        IO.puts("   Estimated cost: $#{estimate_storage_cost(cost_diff.storage.used)} USD")
      end

      # Additional info
      if options[:run_time] do
        IO.puts("⏱️  Run Time: #{options[:run_time]} seconds")
      end

      if options[:pages_processed] do
        IO.puts("📄 Pages Processed: #{options[:pages_processed]}")
      end

      if options[:items_created] do
        IO.puts("📊 Items Created: #{options[:items_created]}")
      end

      total_estimated_cost =
        estimate_compute_cost(cost_diff.compute.used) +
          estimate_data_transfer_cost(cost_diff.data_transfer.used) +
          estimate_storage_cost(cost_diff.storage.used)

      if total_estimated_cost > 0 do
        IO.puts("💸 Total Estimated Cost: $#{Float.round(total_estimated_cost, 4)} USD")
      end

      IO.puts("ℹ️  Note: Usage statistics may take 1-5 minutes to update")
      IO.puts("=" |> String.duplicate(50))

      cost_diff
    else
      %{compute: %{used: 0}, data_transfer: %{used: 0}, storage: %{used: 0}}
    end
  end

  @doc """
  Waits for usage statistics to update and retries getting final usage.
  """
  def wait_for_usage_update(client, initial_usage, max_retries \\ 3) do
    record_mode = System.get_env("REQORD") != nil

    if record_mode do
      wait_for_record_mode_update(client, initial_usage, max_retries)
    else
      wait_for_replay_mode_update(client, initial_usage)
    end
  end

  defp wait_for_record_mode_update(client, initial_usage, max_retries) do
    IO.puts("⏳ Waiting for usage statistics to update...")

    Enum.reduce_while(1..max_retries, initial_usage, fn attempt, _acc ->
      # Exponential backoff
      :timer.sleep(2000 * attempt)

      case get_usage(client) do
        {:ok, new_usage} ->
          handle_usage_update(initial_usage, new_usage, attempt, max_retries)

        {:error, _error} ->
          {:halt, initial_usage}
      end
    end)
  end

  defp wait_for_replay_mode_update(client, initial_usage) do
    case get_usage(client) do
      {:ok, usage} -> usage
      {:error, _} -> initial_usage
    end
  end

  defp handle_usage_update(initial_usage, new_usage, attempt, max_retries) do
    cost_diff = calculate_cost_diff(initial_usage, new_usage)

    cond do
      cost_diff.compute.used > 0 ->
        IO.puts("✅ Usage statistics updated after #{attempt} attempt(s)")
        {:halt, new_usage}

      attempt < max_retries ->
        IO.puts("⏳ Still waiting... (attempt #{attempt}/#{max_retries})")
        {:cont, new_usage}

      true ->
        IO.puts("⚠️  Usage statistics may not have updated yet")
        {:halt, new_usage}
    end
  end

  # Private functions

  defp calculate_metric_diff(initial_usage, final_usage, metric_key) do
    # Handle both simple and complex billing structures
    {initial_value, final_value} =
      case {initial_usage, final_usage} do
        # Simple structure
        {%{^metric_key => %{"usage" => init}}, %{^metric_key => %{"usage" => final}}} ->
          {init || 0, final || 0}

        # Complex billing structure - extract from aggregatedUsage or fall back to 0
        {init_map, final_map} when is_map(init_map) and is_map(final_map) ->
          init_val = get_billing_usage(init_map, metric_key)
          final_val = get_billing_usage(final_map, metric_key)
          {init_val, final_val}

        _ ->
          {0, 0}
      end

    used = final_value - initial_value

    %{
      initial: initial_value,
      final: final_value,
      used: used,
      limit: get_in(final_usage, [metric_key, "limit"])
    }
  end

  # Helper to extract usage from complex billing structure
  defp get_billing_usage(usage_map, "compute") do
    # Look for compute units in the new monthly service usage format or legacy aggregated usage
    get_in(usage_map, ["monthlyServiceUsage", "ACTOR_COMPUTE_UNITS", "quantity"]) ||
      get_in(usage_map, ["aggregatedUsage", "ACTOR_COMPUTE_UNITS", "quantity"]) || 0
  end

  defp get_billing_usage(usage_map, "dataTransfer") do
    # Look for data transfer in the new format or legacy format
    external =
      get_in(usage_map, ["monthlyServiceUsage", "DATA_TRANSFER_EXTERNAL_GBYTES", "quantity"]) ||
        get_in(usage_map, ["aggregatedUsage", "DATA_TRANSFER_GBYTES", "quantity"]) || 0

    internal =
      get_in(usage_map, ["monthlyServiceUsage", "DATA_TRANSFER_INTERNAL_GBYTES", "quantity"]) || 0

    external + internal
  end

  defp get_billing_usage(usage_map, "storage") do
    # Look for storage in the new format or legacy format (dataset + kv store)
    dataset_storage =
      get_in(usage_map, ["monthlyServiceUsage", "DATASET_TIMED_STORAGE_GBYTE_HOURS", "quantity"]) ||
        get_in(usage_map, ["aggregatedUsage", "DATASET_TIMED_STORAGE_GBYTE_HOURS", "quantity"]) ||
        0

    kv_storage =
      get_in(usage_map, [
        "monthlyServiceUsage",
        "KEY_VALUE_STORE_TIMED_STORAGE_GBYTE_HOURS",
        "quantity"
      ]) ||
        get_in(usage_map, [
          "aggregatedUsage",
          "KEY_VALUE_STORE_TIMED_STORAGE_GBYTE_HOURS",
          "quantity"
        ]) || 0

    dataset_storage + kv_storage
  end

  defp get_billing_usage(_usage_map, _metric_key), do: 0

  # Apify pricing estimates (as of 2024, may vary by plan)
  defp estimate_compute_cost(compute_units) when compute_units > 0 do
    # Approximate $0.25 per compute unit for pay-as-you-go
    Float.round(compute_units * 0.25, 4)
  end

  defp estimate_compute_cost(_), do: 0.0

  defp estimate_data_transfer_cost(bytes) when bytes > 0 do
    # Approximate $0.10 per GB
    gb = bytes / (1024 * 1024 * 1024)
    Float.round(gb * 0.10, 4)
  end

  defp estimate_data_transfer_cost(_), do: 0.0

  defp estimate_storage_cost(bytes) when bytes > 0 do
    # Storage is usually very cheap, approximate $0.02 per GB per month
    gb = bytes / (1024 * 1024 * 1024)
    Float.round(gb * 0.02, 4)
  end

  defp estimate_storage_cost(_), do: 0.0

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"

  defp format_bytes(bytes) when bytes < 1024 * 1024 do
    "#{Float.round(bytes / 1024, 2)} KB"
  end

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024 do
    "#{Float.round(bytes / (1024 * 1024), 2)} MB"
  end

  defp format_bytes(bytes) do
    "#{Float.round(bytes / (1024 * 1024 * 1024), 2)} GB"
  end
end
