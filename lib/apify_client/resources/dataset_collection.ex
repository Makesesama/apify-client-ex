defmodule ApifyClient.Resources.DatasetCollection do
  @moduledoc """
  Client for managing datasets collection.

  Provides methods for listing, creating, and searching datasets.
  """

  use ApifyClient.Base.ResourceCollectionClient, resource_path: "datasets"

  @type list_options :: [
          {:unnamed, boolean()}
          | {:offset, non_neg_integer()}
          | {:limit, non_neg_integer()}
          | {:desc, boolean()}
        ]

  @doc """
  Lists datasets.

  ## Options

    * `:unnamed` - If true, includes unnamed datasets (default: false)
    * `:offset` - Number of datasets to skip (default: 0)
    * `:limit` - Maximum number of datasets to return (default: 1000)
    * `:desc` - If true, sorts in descending order (default: false)

  ## Examples

      iex> datasets |> DatasetCollection.list()
      {:ok, %{"data" => %{"items" => [...], "total" => 100}}}

      iex> datasets |> DatasetCollection.list(unnamed: true, limit: 10)
      {:ok, %{"data" => %{"items" => [...], "total" => 5}}}
  """
  @spec list(t(), list_options()) :: {:ok, map()} | {:error, Error.t()}
  def list(collection, options) do
    params = build_dataset_list_params(options)
    HTTPClient.get(collection.http_client, url(collection), params: params)
  end

  @doc """
  Creates a new dataset.

  ## Parameters

    * `dataset_data` - Dataset configuration

  ## Optional fields

    * `name` - Dataset name (if not provided, will be unnamed)

  ## Examples

      iex> datasets |> DatasetCollection.create(%{name: "my-dataset"})
      {:ok, %{"id" => "dataset_id", ...}}

      iex> datasets |> DatasetCollection.create(%{})
      {:ok, %{"id" => "dataset_id", "name" => nil, ...}}
  """
  @spec create(t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(collection, dataset_data \\ %{}) do
    super(collection, dataset_data)
  end

  @doc """
  Gets or creates a dataset by name.

  If a dataset with the given name exists, returns it. Otherwise, creates a new one.

  ## Examples

      iex> datasets |> DatasetCollection.get_or_create("my-dataset")
      {:ok, %{"id" => "dataset_id", "name" => "my-dataset", ...}}
  """
  @spec get_or_create(t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def get_or_create(collection, name, dataset_data \\ %{}) do
    super(collection, name, dataset_data)
  end

  # Private helper functions

  defp build_dataset_list_params(options) do
    options
    |> Enum.reduce(%{}, fn
      {:offset, value}, acc when is_integer(value) and value >= 0 ->
        Map.put(acc, "offset", value)

      {:limit, value}, acc when is_integer(value) and value > 0 ->
        Map.put(acc, "limit", value)

      {:desc, true}, acc ->
        Map.put(acc, "desc", 1)

      {:desc, false}, acc ->
        Map.put(acc, "desc", 0)

      {:unnamed, true}, acc ->
        Map.put(acc, "unnamed", 1)

      {:unnamed, false}, acc ->
        Map.put(acc, "unnamed", 0)

      _, acc ->
        acc
    end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
