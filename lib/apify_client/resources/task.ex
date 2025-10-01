defmodule ApifyClient.Resources.Task do
  @moduledoc """
  Client for managing a specific task.
  """

  use ApifyClient.Base.ResourceClient, resource_path: "actor-tasks"

  @doc """
  Starts the task and returns the run information.
  """
  @spec call(t(), any(), map()) :: {:ok, map()} | {:error, Error.t()}
  def call(task, input, options \\ %{}) do
    params = Map.take(options, [:build, :memory, :timeout, :wait_for_finish])
    HTTPClient.post(task.http_client, url(task, "runs"), input, params: params)
  end
end
