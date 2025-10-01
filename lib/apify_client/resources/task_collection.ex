defmodule ApifyClient.Resources.TaskCollection do
  @moduledoc """
  Client for managing tasks collection.
  """

  use ApifyClient.Base.ResourceCollectionClient, resource_path: "actor-tasks"
end
