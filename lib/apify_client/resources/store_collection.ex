defmodule ApifyClient.Resources.StoreCollection do
  @moduledoc """
  Client for browsing the Apify Store.

  Provides methods for searching and filtering actors available in the Apify Store.
  """

  use ApifyClient.Base.ResourceCollectionClient, resource_path: "store"

  @type search_options :: [
          {:search, String.t()}
          | {:category, String.t()}
          | {:username, String.t()}
          | {:pricing, String.t()}
          | {:sortBy, String.t()}
          | {:offset, non_neg_integer()}
          | {:limit, non_neg_integer()}
          | {:desc, boolean()}
        ]

  @doc """
  Searches actors in the Apify Store.

  ## Options

    * `:search` - Search term to filter actors by name or description
    * `:category` - Category to filter by (e.g., "ECOMMERCE", "SOCIAL_MEDIA")
    * `:username` - Filter by actor author username
    * `:pricing` - Pricing model filter ("FREE", "PAID", "BOTH")
    * `:sortBy` - Sort criteria ("popularity", "relevance", "lastUpdate", "created")
    * `:offset` - Number of actors to skip (default: 0)
    * `:limit` - Maximum number of actors to return (default: 40)
    * `:desc` - If true, sorts in descending order (default: true)

  ## Examples

      iex> store |> StoreCollection.list()
      {:ok, %{"data" => %{"items" => [...], "total" => 1000}}}

      iex> store |> StoreCollection.list(%{
      ...>   search: "web scraper",
      ...>   category: "ECOMMERCE",
      ...>   pricing: "FREE",
      ...>   limit: 20
      ...> })
      {:ok, %{"data" => %{"items" => [...], "total" => 50}}}
  """
  @spec list(t(), search_options()) :: {:ok, map()} | {:error, Error.t()}
  def list(collection, options) do
    params = build_search_params(options)
    HTTPClient.get(collection.http_client, url(collection), params: params)
  end

  # Private helper functions

  defp build_search_params(options) do
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

      {key, value}, acc when key in [:search, :category, :username, :pricing, :sortBy] ->
        Map.put(acc, Atom.to_string(key), value)

      _, acc ->
        acc
    end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
