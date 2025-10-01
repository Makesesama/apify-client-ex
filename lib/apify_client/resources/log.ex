defmodule ApifyClient.Resources.Log do
  @moduledoc """
  Client for accessing actor run logs.

  Provides methods for getting and streaming logs from actor runs.
  """

  alias ApifyClient.{Config, Error, HTTPClient}

  @type t :: %__MODULE__{
          client: ApifyClient.t(),
          build_or_run_id: String.t(),
          base_url: String.t(),
          http_client: HTTPClient.t()
        }

  @enforce_keys [:client, :build_or_run_id, :base_url, :http_client]
  defstruct [:client, :build_or_run_id, :base_url, :http_client]

  @doc """
  Creates a new log client instance.
  """
  @spec new(ApifyClient.t(), String.t()) :: t()
  def new(client, build_or_run_id) do
    %__MODULE__{
      client: client,
      build_or_run_id: build_or_run_id,
      base_url: Config.api_url(client.config),
      http_client: client.http_client
    }
  end

  @doc """
  Gets the complete log as a string.

  ## Examples

      iex> log |> Log.get()
      {:ok, "2023-01-01 12:00:00 Actor started\\n..."}
  """
  @spec get(t()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  def get(log) do
    HTTPClient.get(log.http_client, url(log))
  end

  @doc """
  Streams the log content.

  Returns a stream that yields log chunks as they become available.

  ## Examples

      iex> {:ok, stream} = log |> Log.stream()
      iex> stream |> Enum.each(&IO.write/1)
  """
  @spec stream(t()) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def stream(log) do
    HTTPClient.stream(log.http_client, url(log))
  end

  # Private helper functions

  defp url(log) do
    # Determine if this is a build or run ID by checking the format
    # Build IDs typically start with build numbers, run IDs with different patterns
    # For simplicity, we'll check both possible endpoints
    "#{log.base_url}/logs/#{log.build_or_run_id}"
  end
end
