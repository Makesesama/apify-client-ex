defmodule ApifyClient.Resources.ActorIntegrationTest do
  @moduledoc """
  Integration tests for Actor resource using ReqOrd cassettes.

  These tests demonstrate ReqOrd's recording and replay functionality with real Apify API calls.

  ## Setup

  To record new cassettes with real API calls:

      APIFY_TOKEN=your_token REQORD=all mix test test/apify_client/resources/actor_integration_test.exs

  To run tests in replay mode (no network calls):

      mix test test/apify_client/resources/actor_integration_test.exs

  ## Prerequisites

  You need a valid Apify API token to record cassettes. You can get one from:
  https://console.apify.com/account/integrations
  """

  use Reqord.Case

  alias ApifyClient.Resources.Actor

  @moduletag :integration

  defp default_stub_name, do: ApifyClient.ReqStub

  setup do
    client = ApifyClientTest.ReqordSetup.setup_test_client()
    {:ok, client: client}
  end

  test "fetches public actor information", %{client: client} do
    # Use a well-known public actor that should always exist
    actor_name = "apify/web-scraper"

    actor_client = Actor.new(client, actor_name)

    {:ok, actor_data} = Actor.get(actor_client)

    # Verify the response structure
    assert is_map(actor_data)
    assert is_binary(actor_data["id"])  # API returns the actual numeric ID
    assert is_binary(actor_data["name"])
    assert is_binary(actor_data["username"])
    assert is_map(actor_data["stats"])

    # The username should match what we expect
    assert actor_data["username"] == "apify"
  end

  test "lists actors with pagination", %{client: client} do
    actors_collection = ApifyClient.actors(client)

    {:ok, actors_list} = ApifyClient.Resources.ActorCollection.list(
      actors_collection,
      limit: 5,
      offset: 0
    )

    # Verify the response structure
    assert is_map(actors_list)
    assert is_list(actors_list["items"])
    assert is_integer(actors_list["count"]) and actors_list["count"] >= 0
    assert actors_list["limit"] == 5
    assert actors_list["offset"] == 0
  end

  test "handles non-existent actor gracefully", %{client: client} do
    # Use an actor ID that definitely doesn't exist
    non_existent_id = "non-existent-actor-deterministic"

    actor_client = Actor.new(client, non_existent_id)

    {:error, error} = Actor.get(actor_client)

    # Verify we get a proper error response
    assert %ApifyClient.Error{type: :not_found_error} = error
  end

  test "fetches actor builds", %{client: client} do
    # Use a public actor with builds
    actor_id = "apify/web-scraper"

    actor_client = Actor.new(client, actor_id)
    builds_collection = Actor.builds(actor_client)

    {:ok, builds_list} = ApifyClient.Resources.BuildCollection.list(
      builds_collection,
      limit: 3
    )

    # Verify the response structure
    assert is_map(builds_list)
    assert is_list(builds_list["items"])

    if length(builds_list["items"]) > 0 do
      build = List.first(builds_list["items"])
      assert is_binary(build["id"])
      # actorId might be nil in some API responses
      if build["actorId"] do
        assert is_binary(build["actorId"])
        assert build["actorId"] == actor_id
      end
    end
  end

  test "fetches actor runs", %{client: client} do
    # Use a public actor that likely has runs
    actor_id = "apify/web-scraper"

    actor_client = Actor.new(client, actor_id)
    runs_collection = Actor.runs(actor_client)

    {:ok, runs_list} = ApifyClient.Resources.RunCollection.list(
      runs_collection,
      limit: 3
    )

    # Verify the response structure
    assert is_map(runs_list)
    assert is_list(runs_list["items"])

    if length(runs_list["items"]) > 0 do
      run = List.first(runs_list["items"])
      assert is_binary(run["id"])
      assert is_binary(run["actorId"])
      assert run["actorId"] == actor_id
    end
  end
end