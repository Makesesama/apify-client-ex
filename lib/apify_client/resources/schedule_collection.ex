defmodule ApifyClient.Resources.ScheduleCollection do
  @moduledoc """
  Client for managing schedules collection.

  Provides methods for listing, creating, and searching schedules.
  """

  use ApifyClient.Base.ResourceCollectionClient, resource_path: "schedules"

  @type create_schedule_options :: %{
          optional(:name) => String.t(),
          optional(:title) => String.t(),
          optional(:timezone) => String.t(),
          optional(:isEnabled) => boolean(),
          optional(:isExclusive) => boolean(),
          optional(:description) => String.t(),
          cronExpression: String.t(),
          actions: [map()]
        }

  @doc """
  Creates a new schedule.

  ## Parameters

    * `schedule_data` - Schedule configuration

  ## Required fields

    * `cronExpression` - Cron expression defining when to run
    * `actions` - List of actions to perform when schedule triggers

  ## Optional fields

    * `name` - Schedule name
    * `title` - Schedule title
    * `timezone` - Timezone for the schedule (default: "UTC")
    * `isEnabled` - Whether the schedule is enabled (default: true)
    * `isExclusive` - Whether the schedule runs exclusively (default: false)
    * `description` - Schedule description

  ## Examples

      iex> schedules |> ScheduleCollection.create(%{
      ...>   name: "daily-scraper",
      ...>   cronExpression: "0 9 * * *",
      ...>   timezone: "UTC",
      ...>   actions: [%{
      ...>     type: "RUN_ACTOR",
      ...>     actorId: "actor123",
      ...>     input: %{startUrls: ["https://example.com"]}
      ...>   }]
      ...> })
      {:ok, %{"id" => "schedule_id", ...}}
  """
  @spec create(t(), create_schedule_options()) :: {:ok, map()} | {:error, Error.t()}
  def create(collection, schedule_data) do
    super(collection, schedule_data)
  end
end
