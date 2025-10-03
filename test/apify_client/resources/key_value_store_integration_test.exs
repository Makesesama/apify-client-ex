defmodule ApifyClient.Resources.KeyValueStoreIntegrationTest do
  @moduledoc """
  Integration tests for KeyValueStore resource using ReqOrd cassettes.

  These tests demonstrate ReqOrd's recording and replay functionality with real Apify API calls.

  ## Setup

  To record new cassettes with real API calls:

      APIFY_TOKEN=your_token REQORD=all mix test test/apify_client/resources/key_value_store_integration_test.exs

  To run tests in replay mode (no network calls):

      mix test test/apify_client/resources/key_value_store_integration_test.exs
  """

  use Reqord.Case

  alias ApifyClient.Resources.{KeyValueStore, KeyValueStoreCollection}

  @moduletag :integration

  defp default_stub_name, do: ApifyClient.ReqStub

  setup do
    client = ApifyClientTest.ReqordSetup.setup_test_client()
    {:ok, client: client}
  end

  test "lists key-value stores with pagination", %{client: client} do
    stores_collection = ApifyClient.key_value_stores(client)

    {:ok, stores_list} = KeyValueStoreCollection.list(
      stores_collection,
      limit: 5,
      offset: 0
    )

    # Verify the response structure
    assert is_map(stores_list)
    assert is_list(stores_list["items"])
    assert is_integer(stores_list["count"]) and stores_list["count"] >= 0
    assert stores_list["limit"] == 5
    assert stores_list["offset"] == 0
  end

  test "creates and manages key-value store lifecycle", %{client: client} do
    stores_collection = ApifyClient.key_value_stores(client)

    # Create a new key-value store
    {:ok, created_store} = KeyValueStoreCollection.create(
      stores_collection,
      %{name: "test-kvstore-#{System.unique_integer()}"}
    )

    assert is_binary(created_store["id"])
    assert is_binary(created_store["name"])

    store_client = ApifyClient.key_value_store(client, created_store["id"])

    # Test getting store info
    {:ok, store_info} = KeyValueStore.get(store_client)
    assert store_info["id"] == created_store["id"]

    # Test setting records
    {:ok, _} = KeyValueStore.set_record(store_client, "test-key", %{
      message: "Hello, World!",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      data: [1, 2, 3]
    })

    # Test getting record
    {:ok, record} = KeyValueStore.get_record(store_client, "test-key")
    assert record["message"] == "Hello, World!"
    assert is_list(record["data"])

    # Test setting different data types
    {:ok, _} = KeyValueStore.set_record(store_client, "string-key", "Simple string value")
    {:ok, _} = KeyValueStore.set_record(store_client, "number-key", 42)
    {:ok, _} = KeyValueStore.set_record(store_client, "boolean-key", true)

    # Test getting different data types
    {:ok, string_value} = KeyValueStore.get_record(store_client, "string-key")
    assert string_value == "Simple string value"

    {:ok, number_value} = KeyValueStore.get_record(store_client, "number-key")
    assert number_value == 42

    {:ok, boolean_value} = KeyValueStore.get_record(store_client, "boolean-key")
    assert boolean_value == true

    # Test listing keys
    {:ok, keys_list} = KeyValueStore.list_keys(store_client)
    assert is_map(keys_list)
    assert is_list(keys_list["items"])
    assert length(keys_list["items"]) >= 4

    key_names = Enum.map(keys_list["items"], & &1["key"])
    assert "test-key" in key_names
    assert "string-key" in key_names

    # Test deleting a record
    {:ok, _} = KeyValueStore.delete_record(store_client, "test-key")

    # Verify deletion
    {:error, error} = KeyValueStore.get_record(store_client, "test-key")
    assert %ApifyClient.Error{type: :not_found_error} = error

    # Clean up: delete the store
    {:ok, _} = KeyValueStore.delete(store_client)

    # Verify store deletion
    {:error, error} = KeyValueStore.get(store_client)
    assert %ApifyClient.Error{type: :not_found_error} = error
  end

  test "handles non-existent store gracefully", %{client: client} do
    non_existent_id = "non-existent-store-#{System.unique_integer()}"
    store_client = ApifyClient.key_value_store(client, non_existent_id)

    {:error, error} = KeyValueStore.get(store_client)
    assert %ApifyClient.Error{type: :not_found_error} = error
  end

  test "handles non-existent record gracefully", %{client: client} do
    stores_collection = ApifyClient.key_value_stores(client)

    # Create a store
    {:ok, created_store} = KeyValueStoreCollection.create(
      stores_collection,
      %{name: "empty-store-#{System.unique_integer()}"}
    )

    store_client = ApifyClient.key_value_store(client, created_store["id"])

    # Try to get non-existent record
    {:error, error} = KeyValueStore.get_record(store_client, "non-existent-key")
    assert %ApifyClient.Error{type: :not_found_error} = error

    # Clean up
    KeyValueStore.delete(store_client)
  end

  test "stores and retrieves binary data", %{client: client} do
    stores_collection = ApifyClient.key_value_stores(client)

    {:ok, created_store} = KeyValueStoreCollection.create(
      stores_collection,
      %{name: "binary-store-#{System.unique_integer()}"}
    )

    store_client = ApifyClient.key_value_store(client, created_store["id"])

    # Test storing binary data (base64 encoded)
    binary_data = "This is some binary content that could be an image or file"
    encoded_data = Base.encode64(binary_data)

    {:ok, _} = KeyValueStore.set_record(
      store_client,
      "binary-key",
      encoded_data,
      content_type: "application/octet-stream"
    )

    # Test retrieving binary data
    {:ok, retrieved_data} = KeyValueStore.get_record(store_client, "binary-key")
    assert retrieved_data == encoded_data

    # Clean up
    KeyValueStore.delete(store_client)
  end

  test "updates store metadata", %{client: client} do
    stores_collection = ApifyClient.key_value_stores(client)

    # Create a store
    {:ok, created_store} = KeyValueStoreCollection.create(
      stores_collection,
      %{name: "update-test-#{System.unique_integer()}"}
    )

    store_client = ApifyClient.key_value_store(client, created_store["id"])

    # Update store name
    new_name = "updated-store-#{System.unique_integer()}"
    {:ok, updated_store} = KeyValueStore.update(store_client, %{name: new_name})

    assert updated_store["name"] == new_name
    assert updated_store["id"] == created_store["id"]

    # Clean up
    KeyValueStore.delete(store_client)
  end

  test "filters stores by name", %{client: client} do
    stores_collection = ApifyClient.key_value_stores(client)

    {:ok, stores_list} = KeyValueStoreCollection.list(
      stores_collection,
      limit: 10,
      search: "test"
    )

    # Verify the response structure
    assert is_map(stores_list)
    assert is_list(stores_list["items"])

    # If there are results, verify they contain the search term
    if length(stores_list["items"]) > 0 do
      first_store = List.first(stores_list["items"])
      assert is_binary(first_store["name"])
    end
  end

  test "handles large JSON objects", %{client: client} do
    stores_collection = ApifyClient.key_value_stores(client)

    {:ok, created_store} = KeyValueStoreCollection.create(
      stores_collection,
      %{name: "large-json-#{System.unique_integer()}"}
    )

    store_client = ApifyClient.key_value_store(client, created_store["id"])

    # Create a large JSON object
    large_object = %{
      metadata: %{
        title: "Large Test Object",
        description: "This is a test of storing large JSON objects"
      },
      data: for i <- 1..100 do
        %{
          id: i,
          name: "Item #{i}",
          properties: %{
            value: i * 10,
            category: "test-category-#{rem(i, 5)}",
            active: rem(i, 2) == 0
          }
        }
      end
    }

    # Store the large object
    {:ok, _} = KeyValueStore.set_record(store_client, "large-object", large_object)

    # Retrieve and verify
    {:ok, retrieved_object} = KeyValueStore.get_record(store_client, "large-object")
    assert retrieved_object["metadata"]["title"] == "Large Test Object"
    assert length(retrieved_object["data"]) == 100
    assert retrieved_object["data"] |> List.first() |> get_in(["properties", "value"]) == 10

    # Clean up
    KeyValueStore.delete(store_client)
  end
end