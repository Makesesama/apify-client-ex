defmodule ApifyClient do
  @moduledoc """
  Official Elixir client library for the Apify API.

  ApifyClient is the official library to access [Apify API](https://docs.apify.com/api/v2) from your
  Elixir applications.

  ## Installation

  Add `apify_client` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:apify_client, "~> 0.1.0"}
    ]
  end
  ```

  ## Basic Usage

  ```elixir
  # Create a client instance
  client = ApifyClient.new(token: "YOUR_API_TOKEN")

  # Run an actor
  {:ok, run} = ApifyClient.actor(client, "apify/web-scraper")
                |> ApifyClient.Actor.call(%{startUrls: [%{url: "https://example.com"}]})

  # Get dataset items
  {:ok, items} = ApifyClient.dataset(client, run.default_dataset_id)
                 |> ApifyClient.Dataset.list_items()
  ```
  """

  alias ApifyClient.{Config, HTTPClient}

  alias ApifyClient.Resources.{
    Actor,
    ActorCollection,
    Build,
    BuildCollection,
    Dataset,
    DatasetCollection,
    KeyValueStore,
    KeyValueStoreCollection,
    RequestQueue,
    RequestQueueCollection,
    Run,
    RunCollection,
    Schedule,
    ScheduleCollection,
    StoreCollection,
    Task,
    TaskCollection,
    User,
    Webhook,
    WebhookCollection,
    WebhookDispatch,
    WebhookDispatchCollection
  }

  @type t :: %__MODULE__{
          config: Config.t(),
          http_client: HTTPClient.t()
        }

  @enforce_keys [:config, :http_client]
  defstruct [:config, :http_client]

  @doc """
  Creates a new ApifyClient instance.

  ## Options

    * `:token` - Your Apify API token (optional, can also be set via APIFY_TOKEN env var)
    * `:base_url` - Base URL for the API (default: "https://api.apify.com")
    * `:public_base_url` - Public base URL for the API (default: "https://api.apify.com")
    * `:max_retries` - Maximum number of retries for failed requests (default: 8)
    * `:min_delay_between_retries_ms` - Minimum delay between retries in milliseconds (default: 500)
    * `:timeout_ms` - Request timeout in milliseconds (default: 360_000)
    * `:user_agent_suffix` - Suffix to append to the User-Agent header

  ## Examples

      iex> client = ApifyClient.new(token: "YOUR_TOKEN")
      %ApifyClient{...}

      iex> client = ApifyClient.new(token: "YOUR_TOKEN", timeout_ms: 60_000)
      %ApifyClient{...}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    config = Config.new(opts)
    http_client = HTTPClient.new(config)

    %__MODULE__{
      config: config,
      http_client: http_client
    }
  end

  @doc """
  Returns an Actor client for the given actor ID or name.

  ## Examples

      iex> client |> ApifyClient.actor("apify/web-scraper")
      %ApifyClient.Resources.Actor{...}

      iex> client |> ApifyClient.actor("ACTOR_ID")
      %ApifyClient.Resources.Actor{...}
  """
  @spec actor(t(), String.t()) :: Actor.t()
  def actor(%__MODULE__{} = client, actor_id) do
    Actor.new(client, actor_id)
  end

  @doc """
  Returns an ActorCollection client for browsing actors.

  ## Examples

      iex> client |> ApifyClient.actors()
      %ApifyClient.Resources.ActorCollection{...}
  """
  @spec actors(t()) :: ActorCollection.t()
  def actors(%__MODULE__{} = client) do
    ActorCollection.new(client)
  end

  @doc """
  Returns a Dataset client for the given dataset ID.

  ## Examples

      iex> client |> ApifyClient.dataset("DATASET_ID")
      %ApifyClient.Resources.Dataset{...}
  """
  @spec dataset(t(), String.t()) :: Dataset.t()
  def dataset(%__MODULE__{} = client, dataset_id) do
    Dataset.new(client, dataset_id)
  end

  @doc """
  Returns a DatasetCollection client for browsing datasets.

  ## Examples

      iex> client |> ApifyClient.datasets()
      %ApifyClient.Resources.DatasetCollection{...}
  """
  @spec datasets(t()) :: DatasetCollection.t()
  def datasets(%__MODULE__{} = client) do
    DatasetCollection.new(client)
  end

  @doc """
  Returns a KeyValueStore client for the given store ID or name.

  ## Examples

      iex> client |> ApifyClient.key_value_store("default")
      %ApifyClient.Resources.KeyValueStore{...}
  """
  @spec key_value_store(t(), String.t()) :: KeyValueStore.t()
  def key_value_store(%__MODULE__{} = client, store_id) do
    KeyValueStore.new(client, store_id)
  end

  @doc """
  Returns a KeyValueStoreCollection client for browsing key-value stores.

  ## Examples

      iex> client |> ApifyClient.key_value_stores()
      %ApifyClient.Resources.KeyValueStoreCollection{...}
  """
  @spec key_value_stores(t()) :: KeyValueStoreCollection.t()
  def key_value_stores(%__MODULE__{} = client) do
    KeyValueStoreCollection.new(client)
  end

  @doc """
  Returns a RequestQueue client for the given queue ID or name.

  ## Examples

      iex> client |> ApifyClient.request_queue("default")
      %ApifyClient.Resources.RequestQueue{...}
  """
  @spec request_queue(t(), String.t()) :: RequestQueue.t()
  def request_queue(%__MODULE__{} = client, queue_id) do
    RequestQueue.new(client, queue_id)
  end

  @doc """
  Returns a RequestQueueCollection client for browsing request queues.

  ## Examples

      iex> client |> ApifyClient.request_queues()
      %ApifyClient.Resources.RequestQueueCollection{...}
  """
  @spec request_queues(t()) :: RequestQueueCollection.t()
  def request_queues(%__MODULE__{} = client) do
    RequestQueueCollection.new(client)
  end

  @doc """
  Returns a Run client for the given run ID.

  ## Examples

      iex> client |> ApifyClient.run("RUN_ID")
      %ApifyClient.Resources.Run{...}
  """
  @spec run(t(), String.t()) :: Run.t()
  def run(%__MODULE__{} = client, run_id) do
    Run.new(client, run_id)
  end

  @doc """
  Returns a RunCollection client for browsing runs.

  ## Examples

      iex> client |> ApifyClient.runs()
      %ApifyClient.Resources.RunCollection{...}
  """
  @spec runs(t()) :: RunCollection.t()
  def runs(%__MODULE__{} = client) do
    RunCollection.new(client)
  end

  @doc """
  Returns a Build client for the given build ID.

  ## Examples

      iex> client |> ApifyClient.build("BUILD_ID")
      %ApifyClient.Resources.Build{...}
  """
  @spec build(t(), String.t()) :: Build.t()
  def build(%__MODULE__{} = client, build_id) do
    Build.new(client, build_id)
  end

  @doc """
  Returns a BuildCollection client for browsing builds.

  ## Examples

      iex> client |> ApifyClient.builds()
      %ApifyClient.Resources.BuildCollection{...}
  """
  @spec builds(t()) :: BuildCollection.t()
  def builds(%__MODULE__{} = client) do
    BuildCollection.new(client)
  end

  @doc """
  Returns a Task client for the given task ID or name.

  ## Examples

      iex> client |> ApifyClient.task("~my-task")
      %ApifyClient.Resources.Task{...}
  """
  @spec task(t(), String.t()) :: Task.t()
  def task(%__MODULE__{} = client, task_id) do
    Task.new(client, task_id)
  end

  @doc """
  Returns a TaskCollection client for browsing tasks.

  ## Examples

      iex> client |> ApifyClient.tasks()
      %ApifyClient.Resources.TaskCollection{...}
  """
  @spec tasks(t()) :: TaskCollection.t()
  def tasks(%__MODULE__{} = client) do
    TaskCollection.new(client)
  end

  @doc """
  Returns a Schedule client for the given schedule ID or name.

  ## Examples

      iex> client |> ApifyClient.schedule("my-schedule")
      %ApifyClient.Resources.Schedule{...}
  """
  @spec schedule(t(), String.t()) :: Schedule.t()
  def schedule(%__MODULE__{} = client, schedule_id) do
    Schedule.new(client, schedule_id)
  end

  @doc """
  Returns a ScheduleCollection client for browsing schedules.

  ## Examples

      iex> client |> ApifyClient.schedules()
      %ApifyClient.Resources.ScheduleCollection{...}
  """
  @spec schedules(t()) :: ScheduleCollection.t()
  def schedules(%__MODULE__{} = client) do
    ScheduleCollection.new(client)
  end

  @doc """
  Returns a User client for the given user ID or username.
  Use "me" or "~me" to get the current user.

  ## Examples

      iex> client |> ApifyClient.user("me")
      %ApifyClient.Resources.User{...}

      iex> client |> ApifyClient.user("~username")
      %ApifyClient.Resources.User{...}
  """
  @spec user(t(), String.t()) :: User.t()
  def user(%__MODULE__{} = client, user_id) do
    User.new(client, user_id)
  end

  @doc """
  Returns a Webhook client for the given webhook ID.

  ## Examples

      iex> client |> ApifyClient.webhook("WEBHOOK_ID")
      %ApifyClient.Resources.Webhook{...}
  """
  @spec webhook(t(), String.t()) :: Webhook.t()
  def webhook(%__MODULE__{} = client, webhook_id) do
    Webhook.new(client, webhook_id)
  end

  @doc """
  Returns a WebhookCollection client for browsing webhooks.

  ## Examples

      iex> client |> ApifyClient.webhooks()
      %ApifyClient.Resources.WebhookCollection{...}
  """
  @spec webhooks(t()) :: WebhookCollection.t()
  def webhooks(%__MODULE__{} = client) do
    WebhookCollection.new(client)
  end

  @doc """
  Returns a WebhookDispatch client for the given dispatch ID.

  ## Examples

      iex> client |> ApifyClient.webhook_dispatch("DISPATCH_ID")
      %ApifyClient.Resources.WebhookDispatch{...}
  """
  @spec webhook_dispatch(t(), String.t()) :: WebhookDispatch.t()
  def webhook_dispatch(%__MODULE__{} = client, dispatch_id) do
    WebhookDispatch.new(client, dispatch_id)
  end

  @doc """
  Returns a WebhookDispatchCollection client for browsing webhook dispatches.

  ## Examples

      iex> client |> ApifyClient.webhook_dispatches()
      %ApifyClient.Resources.WebhookDispatchCollection{...}
  """
  @spec webhook_dispatches(t()) :: WebhookDispatchCollection.t()
  def webhook_dispatches(%__MODULE__{} = client) do
    WebhookDispatchCollection.new(client)
  end

  @doc """
  Returns a StoreCollection client for browsing the Apify Store.

  ## Examples

      iex> client |> ApifyClient.store()
      %ApifyClient.Resources.StoreCollection{...}
  """
  @spec store(t()) :: StoreCollection.t()
  def store(%__MODULE__{} = client) do
    StoreCollection.new(client)
  end
end
