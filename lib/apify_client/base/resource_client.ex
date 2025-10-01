defmodule ApifyClient.Base.ResourceClient do
  @moduledoc """
  Base module for individual resource clients (e.g., a specific actor, dataset, etc.).
  """

  alias ApifyClient.{Error, HTTPClient}

  @type client :: ApifyClient.t()

  @callback resource_path() :: String.t()

  defmacro __using__(opts \\ []) do
    resource_path = Keyword.get(opts, :resource_path)

    quote do
      @behaviour ApifyClient.Base.ResourceClient

      alias ApifyClient.{Error, HTTPClient}

      @type t :: %__MODULE__{
              client: ApifyClient.t(),
              id: String.t() | nil,
              base_url: String.t(),
              public_base_url: String.t(),
              http_client: HTTPClient.t()
            }

      @enforce_keys [:client, :base_url, :public_base_url, :http_client]
      defstruct [:client, :id, :base_url, :public_base_url, :http_client]

      @doc """
      Creates a new resource client instance.
      """
      @spec new(ApifyClient.t()) :: t()
      def new(client) do
        new(client, nil)
      end

      @doc """
      Creates a new resource client instance with a specific resource ID.
      """
      @spec new(ApifyClient.t(), String.t() | nil) :: t()
      def new(client, id) do
        %__MODULE__{
          client: client,
          id: id,
          base_url: ApifyClient.Config.api_url(client.config),
          public_base_url: ApifyClient.Config.public_api_url(client.config),
          http_client: client.http_client
        }
      end

      unquote(
        if resource_path do
          quote do
            def resource_path, do: unquote(resource_path)
          end
        end
      )

      @doc """
      Builds the URL for this resource.
      """
      @spec url(t()) :: String.t()
      def url(%__MODULE__{id: nil, base_url: base_url}) do
        "#{base_url}/#{resource_path()}"
      end

      def url(%__MODULE__{id: id, base_url: base_url}) do
        safe_id = safe_id(id)
        "#{base_url}/#{resource_path()}/#{safe_id}"
      end

      @doc """
      Builds the URL for this resource with an additional path.
      """
      @spec url(t(), String.t()) :: String.t()
      def url(resource, path) do
        "#{url(resource)}/#{path}"
      end

      @doc """
      Builds the public URL for this resource.
      """
      @spec public_url(t()) :: String.t()
      def public_url(%__MODULE__{id: nil, public_base_url: base_url}) do
        "#{base_url}/#{resource_path()}"
      end

      def public_url(%__MODULE__{id: id, public_base_url: base_url}) do
        safe_id = safe_id(id)
        "#{base_url}/#{resource_path()}/#{safe_id}"
      end

      @doc """
      Builds the public URL for this resource with an additional path.
      """
      @spec public_url(t(), String.t()) :: String.t()
      def public_url(resource, path) do
        "#{public_url(resource)}/#{path}"
      end

      @doc """
      Gets the resource data.
      """
      @spec get(t()) :: {:ok, map() | nil} | {:error, Error.t()}
      def get(resource) do
        HTTPClient.get(resource.http_client, url(resource))
      end

      @doc """
      Updates the resource.
      """
      @spec update(t(), map()) :: {:ok, map()} | {:error, Error.t()}
      def update(resource, data) do
        HTTPClient.put(resource.http_client, url(resource), data)
      end

      @doc """
      Deletes the resource.
      """
      @spec delete(t()) :: {:ok, nil} | {:error, Error.t()}
      def delete(resource) do
        HTTPClient.delete(resource.http_client, url(resource))
      end

      # Protected helper functions

      @doc false
      def safe_id(id) when is_binary(id) do
        # URL encode the ID to handle special characters
        URI.encode_www_form(id)
      end

      @doc false
      def build_params(params) when is_map(params) do
        params
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()
      end

      @doc false
      def build_params(params) when is_list(params) do
        params
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()
      end

      defoverridable get: 1, update: 2, delete: 1
    end
  end
end
