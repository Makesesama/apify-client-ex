defmodule ApifyClient.Resources.KeyValueStore do
  @moduledoc """
  Client for managing a specific key-value store.
  """

  use ApifyClient.Base.ResourceClient, resource_path: "key-value-stores"

  @doc """
  Gets a record from the key-value store.
  """
  @spec get_record(t(), String.t()) :: {:ok, any()} | {:error, Error.t()}
  def get_record(store, key) do
    HTTPClient.get(store.http_client, url(store, "records/#{URI.encode_www_form(key)}"))
  end

  @doc """
  Sets a record in the key-value store.
  """
  @spec set_record(t(), String.t(), any(), keyword()) :: {:ok, nil} | {:error, Error.t()}
  def set_record(store, key, value, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/json")

    HTTPClient.put(
      store.http_client,
      url(store, "records/#{URI.encode_www_form(key)}"),
      value,
      content_type: content_type
    )
  end

  @doc """
  Deletes a record from the key-value store.
  """
  @spec delete_record(t(), String.t()) :: {:ok, nil} | {:error, Error.t()}
  def delete_record(store, key) do
    HTTPClient.delete(store.http_client, url(store, "records/#{URI.encode_www_form(key)}"))
  end

  @doc """
  Lists keys in the key-value store.
  """
  @spec list_keys(t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_keys(store, opts \\ []) do
    params = build_params(opts)
    HTTPClient.get(store.http_client, url(store, "keys"), params: params)
  end
end
