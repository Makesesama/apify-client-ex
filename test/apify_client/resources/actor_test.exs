defmodule ApifyClient.Resources.ActorTest do
  use ExUnit.Case, async: true

  alias ApifyClient.Resources.Actor
  alias ApifyClient.{Config, HTTPClient}

  setup do
    config = Config.new(token: "test-token")
    http_client = HTTPClient.new(config)

    client = %ApifyClient{
      config: config,
      http_client: http_client
    }

    actor = Actor.new(client, "test-actor")

    {:ok, actor: actor, client: client}
  end

  describe "new/2" do
    test "creates actor with client and ID", %{client: client} do
      actor = Actor.new(client, "test-actor")

      assert %Actor{
               client: ^client,
               id: "test-actor",
               base_url: "https://api.apify.com/v2",
               http_client: _
             } = actor
    end
  end

  describe "url/1" do
    test "builds correct URL with ID", %{actor: actor} do
      assert Actor.url(actor) == "https://api.apify.com/v2/acts/test-actor"
    end

    test "builds correct URL with path", %{actor: actor} do
      assert Actor.url(actor, "runs") == "https://api.apify.com/v2/acts/test-actor/runs"
    end
  end

  describe "resource_path/0" do
    test "returns correct resource path" do
      assert Actor.resource_path() == "acts"
    end
  end

  describe "safe_id/1" do
    test "URL encodes special characters" do
      assert Actor.safe_id("user/actor") == "user%2Factor"
      assert Actor.safe_id("normal-id") == "normal-id"
    end
  end
end
