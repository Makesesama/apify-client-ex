defmodule ApifyClient.Resources.WebhookDispatch do
  @moduledoc """
  Client for managing a specific webhook dispatch.

  Provides methods for getting webhook dispatch details and status.
  """

  use ApifyClient.Base.ResourceClient, resource_path: "webhook-dispatches"

  @doc """
  Gets the webhook dispatch details.

  ## Examples

      iex> dispatch |> WebhookDispatch.get()
      {:ok, %{"id" => "dispatch_id", "status" => "SUCCEEDED", ...}}
  """
  def get(dispatch) do
    super(dispatch)
  end
end
