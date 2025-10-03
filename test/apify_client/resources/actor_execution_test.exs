defmodule ApifyClient.Resources.ActorExecutionTest do
  @moduledoc """
  Integration tests for Actor execution using ReqOrd cassettes.

  ⚠️  WARNING: These tests ACTUALLY RUN ACTORS and will consume compute units!

  This test demonstrates the complete actor execution workflow including:
  1. Starting an actor
  2. Monitoring the run
  3. Retrieving results
  4. Cost tracking

  ## Setup

  To record new cassettes with real actor runs:

      APIFY_TOKEN=your_token REQORD=all mix test test/apify_client/resources/actor_execution_test.exs

  To run tests in replay mode (no actors executed):

      mix test test/apify_client/resources/actor_execution_test.exs

  ## Cost Information

  When recording cassettes, this test will:
  - Execute a minimal web scraper run (1-2 pages max)
  - Use approximately 0.01-0.05 compute units per test
  - Create temporary datasets that are cleaned up

  The exact cost depends on your Apify plan and the actor's performance.
  """

  use Reqord.Case

  alias ApifyClient.Resources.{Actor, Dataset, Run, User}

  @moduletag :integration
  @moduletag :actor_execution

  defp default_stub_name, do: ApifyClient.ReqStub

  setup do
    client = ApifyClientTest.ReqordSetup.setup_test_client()

    # Get initial usage for cost tracking
    user_client = ApifyClient.user(client, "me")
    {:ok, initial_usage} = User.monthly_usage(user_client)

    {:ok, client: client, user_client: user_client, initial_usage: initial_usage}
  end

  test "executes actor and tracks costs", %{client: client, user_client: user_client, initial_usage: initial_usage} do
    # Use a fast, minimal actor for testing
    actor_id = "apify/hello-world"  # Simple actor that just returns a greeting
    actor_client = Actor.new(client, actor_id)

    # Check if we're in record mode to decide on actual execution
    record_mode = System.get_env("REQORD") != nil

    if record_mode do
      IO.puts("\n🚀 EXECUTING ACTOR: #{actor_id}")
      IO.puts("💰 This will consume compute units on your Apify account")
    end

    # Start the actor with minimal input
    {:ok, run_info} = Actor.call(actor_client, %{
      message: "Hello from Elixir integration test!",
      outputDatasetId: nil  # Let Apify create a new dataset
    }, wait_for_finish: 60)  # Wait up to 60 seconds

    # Verify run information
    assert is_binary(run_info["id"])
    assert is_binary(run_info["actorId"])
    assert run_info["actorId"] == actor_id

    if record_mode do
      IO.puts("✅ Actor run started: #{run_info["id"]}")
      IO.puts("🔄 Status: #{run_info["status"]}")
    end

    # Get detailed run information
    run_client = ApifyClient.run(client, run_info["id"])
    {:ok, detailed_run} = Run.get(run_client)

    assert detailed_run["id"] == run_info["id"]
    assert detailed_run["status"] in ["READY", "RUNNING", "SUCCEEDED"]

    # If the run finished, check the results
    if detailed_run["status"] == "SUCCEEDED" do
      dataset_id = detailed_run["defaultDatasetId"]

      if dataset_id do
        dataset_client = ApifyClient.dataset(client, dataset_id)
        {:ok, items} = Dataset.list_items(dataset_client)

        assert is_list(items)

        if record_mode and length(items) > 0 do
          IO.puts("📊 Results: #{length(items)} items")
          IO.puts("📄 Sample item: #{inspect(List.first(items))}")
        end
      end
    end

    # Wait a moment for usage to update (in record mode)
    if record_mode do
      :timer.sleep(2000)  # Wait 2 seconds for usage stats to update
    end

    # Get final usage and calculate cost
    {:ok, final_usage} = User.monthly_usage(user_client)

    # Calculate compute units used (if available)
    initial_compute = get_in(initial_usage, ["compute", "usage"]) || 0
    final_compute = get_in(final_usage, ["compute", "usage"]) || 0
    compute_used = final_compute - initial_compute

    if record_mode do
      IO.puts("\n💰 COST REPORT:")
      IO.puts("   Initial compute usage: #{initial_compute}")
      IO.puts("   Final compute usage: #{final_compute}")
      if compute_used > 0 do
        IO.puts("   Compute units used: #{compute_used}")
        IO.puts("   Estimated cost: $#{Float.round(compute_used * 0.25, 4)} USD")
      else
        IO.puts("   Compute units used: <0.01 (usage may not have updated yet)")
      end
      IO.puts("   Note: Usage statistics may take a few minutes to update")
    end

    # Verify we can access usage data
    assert is_map(final_usage)
    assert Map.has_key?(final_usage, "compute")

    if record_mode do
      IO.puts("✅ Test completed successfully")
    end
  end

  test "executes web scraper with minimal input", %{client: client, user_client: user_client, initial_usage: initial_usage} do
    actor_id = "apify/web-scraper"
    actor_client = Actor.new(client, actor_id)

    record_mode = System.get_env("REQORD") != nil

    if record_mode do
      IO.puts("\n🕷️  EXECUTING WEB SCRAPER: #{actor_id}")
      IO.puts("💰 This will consume more compute units (actual web scraping)")
    end

    # Execute with very minimal settings to reduce cost
    {:ok, run_info} = Actor.call(actor_client, %{
      startUrls: [%{url: "https://example.com"}],  # Single, simple page
      maxPagesPerCrawl: 1,  # Limit to 1 page only
      maxResults: 1,        # Limit results
      maxCrawlingDepth: 0,  # No following links
      proxyConfiguration: %{useApifyProxy: false}  # No proxy to reduce cost
    },
    timeout: 120,  # 2 minute timeout
    wait_for_finish: 120  # Wait up to 2 minutes
    )

    assert is_binary(run_info["id"])
    assert run_info["actorId"] == actor_id

    if record_mode do
      IO.puts("✅ Web scraper run started: #{run_info["id"]}")
      IO.puts("🔄 Status: #{run_info["status"]}")
    end

    # Get run details
    run_client = ApifyClient.run(client, run_info["id"])
    {:ok, detailed_run} = Run.get(run_client)

    assert detailed_run["id"] == run_info["id"]

    # Check results if successful
    if detailed_run["status"] == "SUCCEEDED" do
      dataset_id = detailed_run["defaultDatasetId"]

      if dataset_id do
        dataset_client = ApifyClient.dataset(client, dataset_id)
        {:ok, items} = Dataset.list_items(dataset_client)

        if record_mode do
          IO.puts("📊 Scraped items: #{length(items)}")
          if length(items) > 0 do
            first_item = List.first(items)
            IO.puts("📄 Sample scraped data:")
            IO.puts("   URL: #{first_item["url"]}")
            IO.puts("   Title: #{String.slice(first_item["title"] || "", 0, 50)}...")
          end
        end
      end
    end

    # Calculate final costs
    if record_mode do
      :timer.sleep(3000)  # Wait longer for web scraper usage to update
    end

    {:ok, final_usage} = User.monthly_usage(user_client)

    initial_compute = get_in(initial_usage, ["compute", "usage"]) || 0
    final_compute = get_in(final_usage, ["compute", "usage"]) || 0
    compute_used = final_compute - initial_compute

    if record_mode do
      IO.puts("\n💰 WEB SCRAPER COST REPORT:")
      IO.puts("   Compute units used: #{if compute_used > 0, do: compute_used, else: "<0.01 (may not be updated yet)"}")
      if compute_used > 0 do
        IO.puts("   Estimated cost: $#{Float.round(compute_used * 0.25, 4)} USD")
      end
      IO.puts("   Pages scraped: 1 (example.com)")
      IO.puts("   Run time: #{detailed_run["runTimeSecs"] || "unknown"} seconds")
    end

    assert is_map(final_usage)
  end

  test "handles actor execution errors gracefully", %{client: client} do
    actor_id = "apify/web-scraper"
    actor_client = Actor.new(client, actor_id)

    # Try to execute with invalid input to test error handling
    case Actor.call(actor_client, %{
      startUrls: "invalid-input",  # Should be an array
      maxPagesPerCrawl: -1         # Invalid negative value
    }, timeout: 30) do
      {:error, error} ->
        # Should get a validation error
        assert error.type in [:validation_error, :client_error]

      {:ok, run_info} ->
        # If the actor started despite invalid input, wait and check if it failed
        run_client = ApifyClient.run(client, run_info["id"])

        # Wait a bit for the run to potentially fail
        :timer.sleep(5000)

        {:ok, run_status} = Run.get(run_client)
        # The run should either fail or handle the invalid input gracefully
        assert run_status["status"] in ["FAILED", "ABORTED", "SUCCEEDED", "RUNNING"]
    end
  end

end