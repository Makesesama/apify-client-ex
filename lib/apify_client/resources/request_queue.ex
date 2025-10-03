defmodule ApifyClient.Resources.RequestQueue do
  @moduledoc """
  Client for managing a specific request queue.
  """

  use ApifyClient.Base.ResourceClient, resource_path: "request-queues"

  @doc """
  Adds a request to the queue.
  """
  @spec add_request(t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def add_request(queue, request) do
    HTTPClient.post(queue.http_client, url(queue, "requests"), request)
  end

  @doc """
  Gets a request from the queue.
  """
  @spec get_request(t(), String.t()) :: {:ok, map() | nil} | {:error, Error.t()}
  def get_request(queue, request_id) do
    HTTPClient.get(queue.http_client, url(queue, "requests/#{URI.encode_www_form(request_id)}"))
  end

  @doc """
  Updates a request in the queue.
  """
  @spec update_request(t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update_request(queue, request_id, request_data) do
    HTTPClient.put(
      queue.http_client,
      url(queue, "requests/#{URI.encode_www_form(request_id)}"),
      request_data
    )
  end

  @doc """
  Deletes a request from the queue.
  """
  @spec delete_request(t(), String.t()) :: {:ok, nil} | {:error, Error.t()}
  def delete_request(queue, request_id) do
    HTTPClient.delete(
      queue.http_client,
      url(queue, "requests/#{URI.encode_www_form(request_id)}")
    )
  end

  @doc """
  Gets the next request from the queue (head of queue).
  """
  @spec get_request(t()) :: {:ok, map() | nil} | {:error, Error.t()}
  def get_request(queue) do
    HTTPClient.get(queue.http_client, url(queue, "head"))
  end

  @doc """
  Gets the head (first N requests) of the queue.
  """
  @spec get_head(t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_head(queue, opts \\ []) do
    params = build_params(opts)
    HTTPClient.get(queue.http_client, url(queue, "head"), params: params)
  end

  @doc """
  Batch adds multiple requests to the queue.
  """
  @spec batch_add_requests(t(), list(map())) :: {:ok, map()} | {:error, Error.t()}
  def batch_add_requests(queue, requests) do
    HTTPClient.post(queue.http_client, url(queue, "requests/batch"), %{requests: requests})
  end

  @doc """
  Lists requests in the queue.
  """
  @spec list_requests(t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_requests(queue, opts \\ []) do
    params = build_params(opts)
    HTTPClient.get(queue.http_client, url(queue, "requests"), params: params)
  end
end
