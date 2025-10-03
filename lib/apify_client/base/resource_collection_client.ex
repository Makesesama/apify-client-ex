defmodule ApifyClient.Base.ResourceCollectionClient do
  @moduledoc """
  Base module for resource collection clients (e.g., actors, datasets list, etc.).
  """

  alias ApifyClient.{Error, HTTPClient}

  @type client :: ApifyClient.t()
  @type pagination_options :: %{
          optional(:offset) => non_neg_integer(),
          optional(:limit) => non_neg_integer(),
          optional(:desc) => boolean()
        }

  @callback resource_path() :: String.t()

  defmacro __using__(opts \\ []) do
    resource_path = Keyword.get(opts, :resource_path)

    quote do
      @behaviour ApifyClient.Base.ResourceCollectionClient

      alias ApifyClient.{Error, HTTPClient}

      @type t :: %__MODULE__{
              client: ApifyClient.t(),
              base_url: String.t(),
              http_client: HTTPClient.t()
            }

      @enforce_keys [:client, :base_url, :http_client]
      defstruct [:client, :base_url, :http_client]

      @doc """
      Creates a new resource collection client instance.
      """
      @spec new(ApifyClient.t()) :: t()
      def new(client) do
        %__MODULE__{
          client: client,
          base_url: ApifyClient.Config.api_url(client.config),
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
      Builds the URL for this resource collection.
      """
      @spec url(t()) :: String.t()
      def url(%__MODULE__{base_url: base_url}) do
        "#{base_url}/#{resource_path()}"
      end

      @doc """
      Builds the URL for this resource collection with an additional path.
      """
      @spec url(t(), String.t()) :: String.t()
      def url(collection, path) do
        "#{url(collection)}/#{path}"
      end

      @doc """
      Lists resources in the collection.
      """
      @spec list(t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
      def list(collection, opts \\ []) do
        params = build_list_params(opts)
        HTTPClient.get(collection.http_client, url(collection), params: params)
      end

      @doc """
      Creates a new resource in the collection.
      """
      @spec create(t(), map()) :: {:ok, map()} | {:error, Error.t()}
      def create(collection, data) do
        HTTPClient.post(collection.http_client, url(collection), data)
      end

      @doc """
      Gets or creates a resource by name.
      If the resource exists, returns it. If not, creates it with the provided data.
      """
      @spec get_or_create(t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
      def get_or_create(collection, name, data) do
        case get_by_name(collection, name) do
          {:ok, nil} -> create(collection, Map.put(data, "name", name))
          {:ok, resource} -> {:ok, resource}
          {:error, _} = error -> error
        end
      end

      # Helper functions

      defp build_list_params(opts) do
        opts
        |> Enum.reduce(%{}, fn
          {:offset, value}, acc when is_integer(value) and value >= 0 ->
            Map.put(acc, "offset", value)

          {:limit, value}, acc when is_integer(value) and value > 0 ->
            Map.put(acc, "limit", value)

          {:desc, true}, acc ->
            Map.put(acc, "desc", 1)

          {:desc, false}, acc ->
            Map.put(acc, "desc", 0)

          {key, value}, acc when is_atom(key) ->
            Map.put(acc, Atom.to_string(key), value)

          {key, value}, acc when is_binary(key) ->
            Map.put(acc, key, value)

          _, acc ->
            acc
        end)
      end

      @doc """
      Gets a resource by name from the collection.
      """
      @spec get_by_name(t(), String.t()) :: {:ok, map() | nil} | {:error, Error.t()}
      def get_by_name(collection, name) do
        with {:ok, %{"data" => %{"items" => items}}} <-
               list(collection, limit: 1000),
             resource when not is_nil(resource) <-
               Enum.find(items, fn item -> item["name"] == name end) do
          {:ok, resource}
        else
          {:ok, _} -> {:ok, nil}
          nil -> {:ok, nil}
          {:error, _} = error -> error
        end
      end

      defoverridable list: 2, create: 2, get_or_create: 3, url: 1, url: 2
    end
  end
end
