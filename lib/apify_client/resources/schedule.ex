defmodule ApifyClient.Resources.Schedule do
  @moduledoc """
  Client for managing a specific schedule.

  Provides methods for getting schedule details, updating schedules, and managing schedule logs.
  """

  use ApifyClient.Base.ResourceClient, resource_path: "schedules"

  @type schedule_update_options :: %{
          optional(:name) => String.t(),
          optional(:title) => String.t(),
          optional(:cronExpression) => String.t(),
          optional(:timezone) => String.t(),
          optional(:isEnabled) => boolean(),
          optional(:isExclusive) => boolean(),
          optional(:description) => String.t(),
          optional(:actions) => [map()]
        }

  @doc """
  Updates the schedule.

  ## Parameters

    * `schedule_data` - Schedule update data

  ## Options

    * `:name` - Schedule name
    * `:title` - Schedule title
    * `:cronExpression` - Cron expression defining when to run
    * `:timezone` - Timezone for the schedule (e.g., "America/New_York")
    * `:isEnabled` - Whether the schedule is enabled
    * `:isExclusive` - Whether the schedule runs exclusively
    * `:description` - Schedule description
    * `:actions` - List of actions to perform when schedule triggers

  ## Examples

      iex> schedule |> Schedule.update(%{
      ...>   cronExpression: "0 9 * * *",
      ...>   timezone: "UTC",
      ...>   isEnabled: true
      ...> })
      {:ok, %{"id" => "schedule_id", ...}}
  """
  @spec update(t(), schedule_update_options()) :: {:ok, map()} | {:error, Error.t()}
  def update(schedule, schedule_data) do
    super(schedule, schedule_data)
  end

  @doc """
  Gets the schedule log.

  Returns the log of the schedule's execution history.

  ## Examples

      iex> schedule |> Schedule.get_log()
      {:ok, "2023-01-01 09:00:00 - Schedule started\\n..."}
  """
  @spec get_log(t()) :: {:ok, String.t() | nil} | {:error, Error.t()}
  def get_log(schedule) do
    HTTPClient.get(schedule.http_client, url(schedule, "log"))
  end
end
