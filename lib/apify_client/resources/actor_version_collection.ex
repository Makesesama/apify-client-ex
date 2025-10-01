defmodule ApifyClient.Resources.ActorVersionCollection do
  @moduledoc """
  Client for managing actor versions collection.

  Provides methods for listing and creating actor versions.
  """

  use ApifyClient.Base.ResourceCollectionClient, resource_path: "actor-versions"

  @type create_version_options :: %{
          optional(:versionNumber) => String.t(),
          optional(:sourceType) => String.t(),
          optional(:sourceCode) => String.t(),
          optional(:baseDockerImage) => String.t(),
          optional(:buildTag) => String.t(),
          optional(:envVars) => [map()],
          optional(:applyEnvVarsToBuild) => boolean(),
          optional(:storages) => [map()]
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
  Creates a new actor version.

  ## Parameters

    * `version_data` - Version configuration

  ## Optional fields

    * `versionNumber` - Version number (e.g., "1.0", "1.1")
    * `sourceType` - Source type ("SOURCE_CODE", "SOURCE_FILES", "GIT_REPO")
    * `sourceCode` - Source code for SOURCE_CODE type
    * `baseDockerImage` - Base Docker image
    * `buildTag` - Build tag
    * `envVars` - Environment variables
    * `applyEnvVarsToBuild` - Whether to apply env vars to build
    * `storages` - Storage configuration

  ## Examples

      iex> versions |> ActorVersionCollection.create(%{
      ...>   versionNumber: "1.1",
      ...>   sourceType: "SOURCE_CODE",
      ...>   sourceCode: "console.log('Hello World v1.1');"
      ...> })
      {:ok, %{"id" => "version_id", ...}}
  """
  @spec create(t(), create_version_options()) :: {:ok, map()} | {:error, Error.t()}
  def create(collection, version_data) do
    super(collection, version_data)
  end
end
