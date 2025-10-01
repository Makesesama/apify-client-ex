defmodule ApifyClient.Resources.ActorCollection do
  @moduledoc """
  Client for managing actors collection.

  Provides methods for listing, creating, and searching actors.
  """

  use ApifyClient.Base.ResourceCollectionClient, resource_path: "acts"

  @type list_options :: [
          {:my, boolean()}
          | {:offset, non_neg_integer()}
          | {:limit, non_neg_integer()}
          | {:desc, boolean()}
          | {:category, String.t()}
          | {:username, String.t()}
          | {:search, String.t()}
        ]

  @doc """
  Lists actors.

  ## Options

    * `:my` - If true, only returns your actors (default: false)
    * `:offset` - Number of actors to skip (default: 0)
    * `:limit` - Maximum number of actors to return (default: 1000)
    * `:desc` - If true, sorts in descending order (default: false)
    * `:category` - Category to filter by
    * `:username` - Username to filter by
    * `:search` - Search term to filter by

  ## Examples

      iex> actors |> ActorCollection.list()
      {:ok, %{"data" => %{"items" => [...], "total" => 100}}}

      iex> actors |> ActorCollection.list(my: true, limit: 10)
      {:ok, %{"data" => %{"items" => [...], "total" => 5}}}
  """
  @spec list(t(), list_options()) :: {:ok, map()} | {:error, Error.t()}
  def list(collection, options) do
    params = build_actor_list_params(options)
    HTTPClient.get(collection.http_client, url(collection), params: params)
  end

  @doc """
  Creates a new actor.

  ## Parameters

    * `actor_data` - Actor configuration

  ## Required fields

    * `name` - Actor name
    * `source_type` - Source type ("SOURCE_CODE", "SOURCE_FILES", "GIT_REPO")

  ## Examples

      iex> actors |> ActorCollection.create(%{
      ...>   name: "my-actor",
      ...>   source_type: "SOURCE_CODE",
      ...>   source_code: "console.log('Hello World');"
      ...> })
      {:ok, %{"id" => "actor_id", ...}}
  """
  @spec create(t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(collection, actor_data) do
    super(collection, actor_data)
  end

  # Private helper functions

  defp build_actor_list_params(options) do
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

      {:my, true}, acc ->
        Map.put(acc, "my", 1)

      {:my, false}, acc ->
        Map.put(acc, "my", 0)

      {key, value}, acc when key in [:category, :username, :search] ->
        Map.put(acc, Atom.to_string(key), value)

      _, acc ->
        acc
    end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
