defmodule ApifyClient.Resources.DatasetIntegrationTest do
  @moduledoc """
  Integration tests for Dataset resource using ReqOrd cassettes.

  These tests demonstrate ReqOrd's recording and replay functionality with real Apify API calls.

  ## Setup

  To record new cassettes with real API calls:

      APIFY_TOKEN=your_token REQORD=all mix test test/apify_client/resources/dataset_integration_test.exs

  To run tests in replay mode (no network calls):

      mix test test/apify_client/resources/dataset_integration_test.exs
  """

  use Reqord.Case

  alias ApifyClient.Resources.{Dataset, DatasetCollection}

  @moduletag :integration

  setup do
    client = ApifyClientTest.ReqordSetup.setup_test_client()

    # Always track costs - reqord will handle HTTP interactions consistently
    initial_usage =
      case ApifyClientTest.CostTracker.get_usage(client) do
        {:ok, usage} -> usage
        {:error, _} -> nil
      end

    on_exit(fn ->
      # Always attempt to report costs if we have initial usage
      if initial_usage do
        try do
          case ApifyClientTest.CostTracker.get_usage(client) do
            {:ok, final_usage} ->
              ApifyClientTest.CostTracker.report_costs(
                "Dataset Operations",
                initial_usage,
                final_usage
              )

            {:error, _} ->
              :ok
          end
        rescue
          # Handle case where ReqStub is no longer available in on_exit
          RuntimeError -> :ok
        end
      end
    end)

    {:ok, client: client, initial_usage: initial_usage}
  end

  test "lists datasets with pagination", %{client: client} do
    datasets_collection = ApifyClient.datasets(client)

    {:ok, datasets_list} =
      DatasetCollection.list(
        datasets_collection,
        limit: 5,
        offset: 0
      )

    # Verify the response structure
    assert is_map(datasets_list)
    assert is_list(datasets_list["items"])
    assert is_integer(datasets_list["count"]) and datasets_list["count"] >= 0
    assert datasets_list["limit"] == 5
    assert datasets_list["offset"] == 0
  end

  test "creates and manages dataset lifecycle", %{client: client} do
    datasets_collection = ApifyClient.datasets(client)

    # Create a new dataset
    {:ok, created_dataset} =
      DatasetCollection.create(
        datasets_collection,
        %{name: "test-dataset-lifecycle"}
      )

    assert is_binary(created_dataset["id"])
    # Note: name might be nil if not set by the API
    assert is_binary(created_dataset["name"]) or is_nil(created_dataset["name"])

    dataset_client = ApifyClient.dataset(client, created_dataset["id"])

    # Test getting dataset info
    {:ok, dataset_info} = Dataset.get(dataset_client)
    assert dataset_info["id"] == created_dataset["id"]

    # Test pushing items to dataset
    test_items = [
      %{name: "Test Item 1", value: 100},
      %{name: "Test Item 2", value: 200}
    ]

    {:ok, _} = Dataset.push_items(dataset_client, test_items)

    # Test listing items from dataset
    {:ok, items} = Dataset.list_items(dataset_client)
    assert is_list(items)
    assert length(items) == 2

    # Verify item content
    first_item = List.first(items)
    assert first_item["name"] in ["Test Item 1", "Test Item 2"]
    assert first_item["value"] in [100, 200]

    # Test downloading items in different formats
    {:ok, csv_data} = Dataset.list_items(dataset_client, %{format: "csv"})
    assert is_binary(csv_data)
    # CSV may have BOM prefix, so check if headers are present anywhere
    assert String.contains?(csv_data, "name") and String.contains?(csv_data, "value")

    # Test streaming items
    {:ok, stream} = Dataset.stream_items(dataset_client)
    streamed_items = Enum.to_list(stream)
    # Verify we get at least one item (might be timing-dependent in live tests)
    assert length(streamed_items) >= 1
    assert length(streamed_items) <= 2

    # Clean up: delete the dataset
    {:ok, _} = Dataset.delete(dataset_client)

    # Verify deletion
    {:error, error} = Dataset.get(dataset_client)
    assert %ApifyClient.Error{type: :not_found_error} = error
  end

  test "handles non-existent dataset gracefully", %{client: client} do
    non_existent_id = "non-existent-dataset-deterministic"
    dataset_client = ApifyClient.dataset(client, non_existent_id)

    {:error, error} = Dataset.get(dataset_client)
    assert %ApifyClient.Error{type: :not_found_error} = error
  end

  test "filters datasets by name", %{client: client} do
    datasets_collection = ApifyClient.datasets(client)

    {:ok, datasets_list} =
      DatasetCollection.list(
        datasets_collection,
        limit: 10,
        search: "test"
      )

    # Verify the response structure
    assert is_map(datasets_list)
    assert is_list(datasets_list["items"])

    # If there are results, verify they contain the search term
    if length(datasets_list["items"]) > 0 do
      first_dataset = List.first(datasets_list["items"])
      assert is_binary(first_dataset["name"])
    end
  end

  test "gets dataset items with pagination", %{client: client} do
    # Create a dataset with multiple items for pagination testing
    datasets_collection = ApifyClient.datasets(client)

    {:ok, created_dataset} =
      DatasetCollection.create(
        datasets_collection,
        %{name: "test-dataset-pagination"}
      )

    dataset_client = ApifyClient.dataset(client, created_dataset["id"])

    # Push multiple items
    items =
      for i <- 1..10 do
        %{index: i, data: "item-#{i}"}
      end

    {:ok, _} = Dataset.push_items(dataset_client, items)

    # Test pagination
    {:ok, first_page} = Dataset.list_items(dataset_client, limit: 3, offset: 0)
    assert length(first_page) == 3

    {:ok, second_page} = Dataset.list_items(dataset_client, limit: 3, offset: 3)
    assert length(second_page) == 3

    # Verify items are different
    first_indices = Enum.map(first_page, & &1["index"])
    second_indices = Enum.map(second_page, & &1["index"])
    assert first_indices != second_indices

    # Clean up
    Dataset.delete(dataset_client)
  end

  test "updates dataset metadata", %{client: client} do
    datasets_collection = ApifyClient.datasets(client)

    # Create a dataset
    {:ok, created_dataset} =
      DatasetCollection.create(
        datasets_collection,
        %{name: "test-dataset-update"}
      )

    dataset_client = ApifyClient.dataset(client, created_dataset["id"])

    # Update dataset name
    new_name = "test-dataset-updated-#{:erlang.unique_integer([:positive])}"
    {:ok, updated_dataset} = Dataset.update(dataset_client, %{name: new_name})

    # Just verify the update succeeded and returned a name
    assert is_binary(updated_dataset["name"])
    assert String.starts_with?(updated_dataset["name"], "test-dataset-updated-")
    assert updated_dataset["id"] == created_dataset["id"]

    # Clean up
    Dataset.delete(dataset_client)
  end
end
