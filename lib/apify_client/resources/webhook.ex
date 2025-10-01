defmodule ApifyClient.Resources.Webhook do
  @moduledoc """
  Client for managing a specific webhook.

  Provides methods for getting webhook details, updating webhooks, testing, and managing dispatches.
  """

  use ApifyClient.Base.ResourceClient, resource_path: "webhooks"

  alias ApifyClient.Resources.WebhookDispatchCollection

  @type webhook_update_options :: %{
          optional(:isAdHoc) => boolean(),
          optional(:eventTypes) => [String.t()],
          optional(:condition) => map(),
          optional(:ignoreSslErrors) => boolean(),
          optional(:doNotRetry) => boolean(),
          optional(:requestUrl) => String.t(),
          optional(:payloadTemplate) => String.t(),
          optional(:headersTemplate) => String.t(),
          optional(:description) => String.t()
        }

  @type webhook_test_options :: %{
          optional(:eventType) => String.t(),
          optional(:eventData) => map()
        }

  @doc """
  Updates the webhook.

  ## Parameters

    * `webhook_data` - Webhook update data

  ## Options

    * `:isAdHoc` - Whether the webhook is ad-hoc
    * `:eventTypes` - List of event types the webhook should respond to
    * `:condition` - Condition for webhook execution
    * `:ignoreSslErrors` - Whether to ignore SSL errors
    * `:doNotRetry` - Whether to disable retries
    * `:requestUrl` - Target URL for webhook requests
    * `:payloadTemplate` - Template for webhook payload
    * `:headersTemplate` - Template for webhook headers
    * `:description` - Webhook description

  ## Examples

      iex> webhook |> Webhook.update(%{
      ...>   eventTypes: ["ACTOR.RUN.SUCCEEDED"],
      ...>   requestUrl: "https://example.com/webhook"
      ...> })
      {:ok, %{"id" => "webhook_id", ...}}
  """
  @spec update(t(), webhook_update_options()) :: {:ok, map()} | {:error, Error.t()}
  def update(webhook, webhook_data) do
    super(webhook, webhook_data)
  end

  @doc """
  Tests the webhook by sending a test payload.

  ## Parameters

    * `options` - Test options

  ## Options

    * `:eventType` - Event type to simulate (e.g., "ACTOR.RUN.SUCCEEDED")
    * `:eventData` - Data to include in the test event

  ## Examples

      iex> webhook |> Webhook.test()
      {:ok, %{"id" => "dispatch_id", ...}}

      iex> webhook |> Webhook.test(%{
      ...>   eventType: "ACTOR.RUN.SUCCEEDED",
      ...>   eventData: %{actorId: "actor123"}
      ...> })
      {:ok, %{"id" => "dispatch_id", ...}}
  """
  @spec test(t(), webhook_test_options()) :: {:ok, map()} | {:error, Error.t()}
  def test(webhook, options \\ %{}) do
    params = build_test_params(options)

    HTTPClient.post(
      webhook.http_client,
      url(webhook, "test"),
      %{},
      params: params
    )
  end

  @doc """
  Returns a client for the webhook's dispatches.

  ## Examples

      iex> webhook |> Webhook.dispatches()
      %ApifyClient.Resources.WebhookDispatchCollection{...}
  """
  @spec dispatches(t()) :: WebhookDispatchCollection.t()
  def dispatches(webhook) do
    WebhookDispatchCollection.new(webhook.client, webhook_id: webhook.id)
  end

  # Private helper functions

  defp build_test_params(options) do
    options
    |> Map.take([:eventType, :eventData])
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
