defmodule ApifyClientTest.ReqordSetup do
  @moduledoc """
  Helper module for setting up ReqOrd in tests.

  This module provides utilities for working with ReqOrd cassettes
  and managing test configurations.
  """

  @doc """
  Sets up a test client with appropriate configuration for recording/replaying.

  In record mode (REQORD=all), uses real API token and records HTTP requests.
  In replay mode (default), uses mock token and replays from cassettes.
  """
  def setup_test_client do
    # Check if we're in record mode (REQORD must be explicitly set to a recording value)
    reqord_value = System.get_env("REQORD")
    record_mode = reqord_value in ["all", "new_episodes", "once"]

    token =
      if record_mode do
        # Try multiple ways to get the token in record mode
        # Alternative name
        apify_token =
          System.get_env("APIFY_TOKEN") ||
            Application.get_env(:apify_client, :test_token) ||
            System.get_env("APIFY_API_TOKEN")

        if apify_token && apify_token != "" do
          apify_token
        else
          raise("APIFY_TOKEN environment variable required when REQORD=#{reqord_value}")
        end
      else
        # Use mock token for replay
        "test-token-for-replay"
      end

    ApifyClient.new(token: token)
  end

  @doc """
  Creates a test actor ID that's safe for both recording and replay.

  Uses well-known public actors that should always be available.
  """
  def test_actor_id, do: "apify/web-scraper"

  @doc """
  Creates a unique non-existent actor ID for error testing.
  """
  def non_existent_actor_id do
    "non-existent-actor-#{System.unique_integer()}"
  end
end
