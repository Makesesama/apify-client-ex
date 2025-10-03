defmodule ApifyClient.Resources.BuildCollection do
  @moduledoc """
  Client for managing builds collection.
  """

  use ApifyClient.Base.ResourceCollectionClient, resource_path: "builds"

  def new(client, opts) do
    actor_id = Keyword.get(opts, :actor_id)

    collection = %__MODULE__{
      client: client,
      base_url: ApifyClient.Config.api_url(client.config),
      http_client: client.http_client
    }

    if actor_id do
      safe_actor_id = ApifyClient.Resources.Actor.safe_id(actor_id)
      %{collection | base_url: "#{collection.base_url}/acts/#{safe_actor_id}"}
    else
      collection
    end
  end

  # Override url function to handle different endpoint patterns
  def url(%__MODULE__{base_url: base_url}) do
    if String.contains?(base_url, "/acts/") do
      "#{base_url}/builds"
    else
      "#{base_url}/actor-builds"
    end
  end

end
