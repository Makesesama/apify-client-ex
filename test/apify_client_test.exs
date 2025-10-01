defmodule ApifyClientTest do
  use ExUnit.Case, async: true

  alias ApifyClient.{Config, Error}

  describe "new/1" do
    test "creates client with default configuration" do
      client = ApifyClient.new()

      assert %ApifyClient{config: %Config{}} = client
      assert client.config.base_url == "https://api.apify.com"
      assert client.config.timeout_ms == 360_000
      assert client.config.max_retries == 8
    end

    test "creates client with custom configuration" do
      client =
        ApifyClient.new(
          token: "test-token",
          base_url: "https://custom.api.com",
          timeout_ms: 60_000,
          max_retries: 3
        )

      assert client.config.token == "test-token"
      assert client.config.base_url == "https://custom.api.com"
      assert client.config.timeout_ms == 60_000
      assert client.config.max_retries == 3
    end

    test "reads token from environment variable" do
      System.put_env("APIFY_TOKEN", "env-token")

      client = ApifyClient.new()

      assert client.config.token == "env-token"

      System.delete_env("APIFY_TOKEN")
    end
  end

  describe "resource methods" do
    setup do
      client = ApifyClient.new(token: "test-token")
      {:ok, client: client}
    end

    test "actor/2 returns Actor client", %{client: client} do
      actor = ApifyClient.actor(client, "test-actor")

      assert %ApifyClient.Resources.Actor{id: "test-actor"} = actor
    end

    test "actors/1 returns ActorCollection client", %{client: client} do
      actors = ApifyClient.actors(client)

      assert %ApifyClient.Resources.ActorCollection{} = actors
    end

    test "dataset/2 returns Dataset client", %{client: client} do
      dataset = ApifyClient.dataset(client, "test-dataset")

      assert %ApifyClient.Resources.Dataset{id: "test-dataset"} = dataset
    end

    test "datasets/1 returns DatasetCollection client", %{client: client} do
      datasets = ApifyClient.datasets(client)

      assert %ApifyClient.Resources.DatasetCollection{} = datasets
    end

    test "key_value_store/2 returns KeyValueStore client", %{client: client} do
      store = ApifyClient.key_value_store(client, "test-store")

      assert %ApifyClient.Resources.KeyValueStore{id: "test-store"} = store
    end

    test "request_queue/2 returns RequestQueue client", %{client: client} do
      queue = ApifyClient.request_queue(client, "test-queue")

      assert %ApifyClient.Resources.RequestQueue{id: "test-queue"} = queue
    end

    test "run/2 returns Run client", %{client: client} do
      run = ApifyClient.run(client, "test-run")

      assert %ApifyClient.Resources.Run{id: "test-run"} = run
    end
  end
end
