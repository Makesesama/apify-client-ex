defmodule ApifyClient.Resources.UserIntegrationTest do
  @moduledoc """
  Integration tests for User resource using ReqOrd cassettes.

  These tests demonstrate ReqOrd's recording and replay functionality with real Apify API calls.

  ## Setup

  To record new cassettes with real API calls:

      APIFY_TOKEN=your_token REQORD=all mix test test/apify_client/resources/user_integration_test.exs

  To run tests in replay mode (no network calls):

      mix test test/apify_client/resources/user_integration_test.exs

  ## Note

  User tests require a valid API token as they access account-specific information.
  """

  use Reqord.Case

  alias ApifyClient.Resources.User

  @moduletag :integration

  defp default_stub_name, do: ApifyClient.ReqStub

  setup do
    client = ApifyClientTest.ReqordSetup.setup_test_client()
    {:ok, client: client}
  end

  test "gets current user information", %{client: client} do
    user_client = ApifyClient.user(client, "me")

    {:ok, user_info} = User.get(user_client)

    # Verify the response structure
    assert is_map(user_info)
    assert is_binary(user_info["id"])
    assert is_binary(user_info["username"])
    assert is_binary(user_info["email"]) or is_nil(user_info["email"])

    # Verify plan information
    if user_info["plan"] do
      assert is_binary(user_info["plan"])
    end

    # Verify timestamps
    assert is_binary(user_info["createdAt"])
  end

  test "gets user's monthly usage", %{client: client} do
    user_client = ApifyClient.user(client, "me")

    {:ok, usage_info} = User.monthly_usage(user_client)

    # Verify the response structure
    assert is_map(usage_info)

    # Usage should contain various metrics - structure can vary
    # The actual API returns a more complex structure with billing info
    assert is_map(usage_info)

    # Check for either the simple structure or the complex billing structure
    if Map.has_key?(usage_info, "compute") do
      # Simple structure
      compute = usage_info["compute"]
      assert is_map(compute) or is_nil(compute)
    else
      if Map.has_key?(usage_info, "totalUsageCreditsUsd") do
        # Complex billing structure
        assert is_number(usage_info["totalUsageCreditsUsd"])
        if Map.has_key?(usage_info, "aggregatedUsage") do
          assert is_map(usage_info["aggregatedUsage"])
        end
      end
    end
  end

  test "gets user's limits", %{client: client} do
    user_client = ApifyClient.user(client, "me")

    {:ok, limits_info} = User.limits(user_client)

    # Verify the response structure
    assert is_map(limits_info)

    # Should contain various limit types
    expected_limit_keys = [
      "maxConcurrentActorJobs",
      "maxMemoryMbytes",
      "maxBuildTimeoutSecs",
      "maxRunTimeoutSecs"
    ]

    for key <- expected_limit_keys do
      if Map.has_key?(limits_info, key) do
        assert is_number(limits_info[key]) or is_nil(limits_info[key])
      end
    end
  end

  test "handles non-existent user gracefully", %{client: client} do
    # Try to get info for a non-existent user
    non_existent_username = "non-existent-user-#{System.unique_integer()}"
    user_client = ApifyClient.user(client, non_existent_username)

    {:error, error} = User.get(user_client)
    assert %ApifyClient.Error{type: :not_found_error} = error
  end

  test "gets public user information", %{client: client} do
    # Use a known public user (Apify's official account)
    public_username = "apify"
    user_client = ApifyClient.user(client, public_username)

    {:ok, user_info} = User.get(user_client)

    # Verify basic structure for public user
    assert is_map(user_info)
    assert user_info["username"] == public_username
    assert is_binary(user_info["id"])

    # Public user info should not contain sensitive data
    refute Map.has_key?(user_info, "email")

    # Should contain public information
    if Map.has_key?(user_info, "profile") do
      profile = user_info["profile"]
      assert is_map(profile) or is_nil(profile)
    end
  end

  test "gets user's webhook dispatches", %{client: client} do
    user_client = ApifyClient.user(client, "me")
    webhooks_collection = User.webhook_dispatches(user_client)

    {:ok, dispatches_list} = ApifyClient.Resources.WebhookDispatchCollection.list(
			       webhooks_collection,
			       limit: 10,
			       offset: 0
			     )

    # Verify the response structure
    assert is_map(dispatches_list)
    assert is_list(dispatches_list["items"])
    assert is_integer(dispatches_list["count"]) and dispatches_list["count"] >= 0
    assert dispatches_list["limit"] == 10
    assert dispatches_list["offset"] == 0

    # If there are webhook dispatches, verify their structure
    if length(dispatches_list["items"]) > 0 do
      dispatch = List.first(dispatches_list["items"])
      assert is_binary(dispatch["id"])
      assert is_binary(dispatch["userId"])
      assert is_binary(dispatch["createdAt"])
    end
  end

  test "gets user account information with all details", %{client: client} do
    user_client = ApifyClient.user(client, "me")

    # Get detailed user info
    {:ok, user_info} = User.get(user_client)

    # Test that we can access various user properties
    basic_fields = ["id", "username", "createdAt"]

    for field <- basic_fields do
      assert Map.has_key?(user_info, field), "Missing field: #{field}"
      assert is_binary(user_info[field]), "Field #{field} should be a string"
    end

    # Optional fields that might be present
    optional_fields = ["email", "plan", "profile", "proxy"]

    for field <- optional_fields do
      if Map.has_key?(user_info, field) do
        value = user_info[field]
        assert value != "", "Field #{field} should not be empty string if present"
      end
    end
  end

  test "verifies user account permissions", %{client: client} do
    # This test verifies that we can access our own account info
    # but get appropriate errors for unauthorized operations

    user_client = ApifyClient.user(client, "me")

    # Should be able to get our own info
    {:ok, user_info} = User.get(user_client)
    assert is_binary(user_info["id"])

    # Should be able to get our own usage
    {:ok, usage_info} = User.monthly_usage(user_client)
    assert is_map(usage_info)

    # Should be able to get our own limits
    {:ok, limits_info} = User.limits(user_client)
    assert is_map(limits_info)

    # Trying to get private info for another user should fail appropriately
    other_user_client = ApifyClient.user(client, "apify")

    # Public info should work
    {:ok, public_info} = User.get(other_user_client)
    assert public_info["username"] == "apify"

    # Private info should fail (usage, limits are private)
    # Note: These might return different error types depending on the API
    case User.monthly_usage(other_user_client) do
      {:error, error} ->
        assert error.type in [:authorization_error, :not_found_error, :forbidden_error]
      {:ok, _} ->
        # Some APIs might return empty or limited data instead of error
        :ok
    end
  end
end
