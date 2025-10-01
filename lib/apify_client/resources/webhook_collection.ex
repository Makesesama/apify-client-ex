defmodule ApifyClient.Resources.WebhookCollection do
  @moduledoc """
  Client for managing webhooks collection.

  Provides methods for listing, creating, and searching webhooks.
  """

  use ApifyClient.Base.ResourceCollectionClient, resource_path: "webhooks"

  @type create_webhook_options :: %{
          optional(:isAdHoc) => boolean(),
          optional(:eventTypes) => [String.t()],
          optional(:condition) => map(),
          optional(:ignoreSslErrors) => boolean(),
          optional(:doNotRetry) => boolean(),
          optional(:payloadTemplate) => String.t(),
          optional(:headersTemplate) => String.t(),
          optional(:description) => String.t(),
          requestUrl: String.t()
        }

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

  @doc """
  Creates a new webhook.

  ## Parameters

    * `webhook_data` - Webhook configuration

  ## Required fields

    * `requestUrl` - Target URL for webhook requests

  ## Optional fields

    * `isAdHoc` - Whether the webhook is ad-hoc (default: false)
    * `eventTypes` - List of event types (default: all actor events)
    * `condition` - Condition for webhook execution
    * `ignoreSslErrors` - Whether to ignore SSL errors (default: false)
    * `doNotRetry` - Whether to disable retries (default: false)
    * `payloadTemplate` - Template for webhook payload
    * `headersTemplate` - Template for webhook headers
    * `description` - Webhook description

  ## Examples

      iex> webhooks |> WebhookCollection.create(%{
      ...>   requestUrl: "https://example.com/webhook",
      ...>   eventTypes: ["ACTOR.RUN.SUCCEEDED", "ACTOR.RUN.FAILED"],
      ...>   description: "Notify on actor completion"
      ...> })
      {:ok, %{"id" => "webhook_id", ...}}
  """
  @spec create(t(), create_webhook_options()) :: {:ok, map()} | {:error, Error.t()}
  def create(collection, webhook_data) do
    super(collection, webhook_data)
  end
end
