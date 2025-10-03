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
    # Convert atom keys to string keys and handle payload
    request_with_string_keys = atomize_to_string_keys(request)

    # Convert payload to JSON string if it's a map/list
    request_with_string_payload =
      case request_with_string_keys["payload"] do
        nil -> request_with_string_keys
        payload when is_binary(payload) -> request_with_string_keys
        payload -> Map.put(request_with_string_keys, "payload", Jason.encode!(payload))
      end

    HTTPClient.post(queue.http_client, url(queue, "requests"), request_with_string_payload)
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
    # Convert atom keys to string keys and handle payload for each request
    requests_with_string_payloads = Enum.map(requests, fn request ->
      request_with_string_keys = atomize_to_string_keys(request)

      case request_with_string_keys["payload"] do
        nil -> request_with_string_keys
        payload when is_binary(payload) -> request_with_string_keys
        payload -> Map.put(request_with_string_keys, "payload", Jason.encode!(payload))
      end
    end)

    HTTPClient.post(queue.http_client, url(queue, "requests/batch"), requests_with_string_payloads)
  end

  @doc """
  Lists requests in the queue.
  """
  @spec list_requests(t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_requests(queue, opts \\ []) do
    params = build_params(opts)
    HTTPClient.get(queue.http_client, url(queue, "requests"), params: params)
  end

  # Helper function to convert atom keys to string keys recursively
  defp atomize_to_string_keys(map) when is_map(map) do
    map
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), atomize_to_string_keys(value)}
      {key, value} -> {key, atomize_to_string_keys(value)}
    end)
    |> Map.new()
  end

  defp atomize_to_string_keys(list) when is_list(list) do
    Enum.map(list, &atomize_to_string_keys/1)
  end

  defp atomize_to_string_keys(value), do: value
end
