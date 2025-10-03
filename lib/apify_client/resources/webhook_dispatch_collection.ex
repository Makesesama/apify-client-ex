defmodule ApifyClient.Resources.WebhookDispatchCollection do
  @moduledoc """
  Client for managing webhook dispatches collection.

  Provides methods for listing webhook dispatches.
  """

  use ApifyClient.Base.ResourceCollectionClient, resource_path: "webhook-dispatches"

  def new(client, opts) do
    webhook_id = Keyword.get(opts, :webhook_id)

    collection = %__MODULE__{
      client: client,
      base_url: ApifyClient.Config.api_url(client.config),
      http_client: client.http_client
    }

    if webhook_id do
      %{collection | base_url: "#{collection.base_url}/webhooks/#{webhook_id}"}
    else
      collection
    end
  end

  # Override url function to handle different endpoint patterns
  def url(%__MODULE__{base_url: base_url}) do
    if String.contains?(base_url, "/webhooks/") do
      "#{base_url}/dispatches"
    else
      "#{base_url}/webhook-dispatches"
    end
  end

  @doc """
  Lists webhook dispatches.

  ## Options

    * `:offset` - Number of dispatches to skip (default: 0)
    * `:limit` - Maximum number of dispatches to return (default: 1000)
    * `:desc` - If true, sorts in descending order (default: false)

  ## Examples

      iex> dispatches |> WebhookDispatchCollection.list()
      {:ok, %{"data" => %{"items" => [...], "total" => 100}}}

      iex> dispatches |> WebhookDispatchCollection.list(limit: 10, desc: true)
      {:ok, %{"data" => %{"items" => [...], "total" => 5}}}
  """
  def list(collection, options) do
    super(collection, options)
  end
end
