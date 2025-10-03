defmodule ApifyClient.Resources.RunCollection do
  @moduledoc """
  Client for managing runs collection.
  """

  use ApifyClient.Base.ResourceCollectionClient, resource_path: "runs"

  def new(client, opts) do
    actor_id = Keyword.get(opts, :actor_id)

    collection = %__MODULE__{
      client: client,
      base_url: ApifyClient.Config.api_url(client.config),
      http_client: client.http_client
    }

    if actor_id do
      %{collection | base_url: "#{collection.base_url}/acts/#{actor_id}"}
    else
      collection
    end
  end

  # Override url function to handle different endpoint patterns
  def url(%__MODULE__{base_url: base_url}) do
    if String.contains?(base_url, "/acts/") do
      "#{base_url}/runs"
    else
      "#{base_url}/actor-runs"
    end
  end

  # Also override the 2-arity version
  def url(collection, path) do
    "#{url(collection)}/#{path}"
  end
end
