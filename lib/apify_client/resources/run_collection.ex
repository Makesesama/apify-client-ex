defmodule ApifyClient.Resources.RunCollection do
  @moduledoc """
  Client for managing runs collection.
  """

  use ApifyClient.Base.ResourceCollectionClient, resource_path: "actor-runs"

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
end
