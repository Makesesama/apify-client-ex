defmodule ApifyClient.Resources.Build do
  @moduledoc """
  Client for managing a specific actor build.
  """

  use ApifyClient.Base.ResourceClient, resource_path: "actor-builds"

  @doc """
  Aborts the build.
  """
  @spec abort(t()) :: {:ok, map()} | {:error, Error.t()}
  def abort(build) do
    HTTPClient.post(build.http_client, url(build, "abort"), %{})
  end
end
