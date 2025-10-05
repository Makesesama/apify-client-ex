defmodule ApifyClient.Examples.ActorRunMonitor do
  @moduledoc """
  Example GenServer that starts an actor and monitors its run in real-time.

  This GenServer demonstrates how to:
  - Start an Apify actor
  - Attach to the running actor
  - Poll for status updates
  - Fetch results when complete
  - Handle errors and retries

  ## Usage

      # Start the monitor
      {:ok, pid} = ApifyClient.Examples.ActorRunMonitor.start_link(
        actor_id: "apify/web-scraper",
        input: %{
          startUrls: [%{url: "https://example.com"}],
          maxPagesPerCrawl: 1
        },
        token: "your_apify_token"
      )

      # Get current status
      ApifyClient.Examples.ActorRunMonitor.get_status(pid)

      # Get results (blocks until complete)
      ApifyClient.Examples.ActorRunMonitor.get_results(pid)

      # Or get current dataset items without waiting for completion
      ApifyClient.Examples.ActorRunMonitor.get_current_dataset_items(pid)

      # Stop monitoring
      GenServer.stop(pid)
  """

  use GenServer
  require Logger

  alias ApifyClient.Resources.{Actor, Run, Dataset}

  # Poll every 2 seconds
  @poll_interval 2_000
  # Max 10 minutes of polling
  @max_poll_attempts 300

  defstruct [
    :client,
    :actor_id,
    :run_id,
    :run_client,
    :dataset_client,
    :status,
    :started_at,
    :finished_at,
    :poll_attempts,
    :dataset_items,
    :stats,
    :error,
    subscribers: []
  ]

  # Client API

  @doc """
  Starts the ActorRunMonitor GenServer.

  ## Options
  - `:actor_id` - The ID of the actor to run (required)
  - `:input` - Input data for the actor (required)
  - `:token` - Apify API token (required unless in ENV)
  - `:poll_interval` - How often to poll for updates in ms (default: 2000)
  - `:wait_for_finish` - Whether to wait for completion (default: false)
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Gets the current status of the actor run.
  """
  def get_status(pid) do
    GenServer.call(pid, :get_status)
  end

  @doc """
  Gets the results from the actor run.
  Blocks until the run is complete.
  """
  def get_results(pid) do
    GenServer.call(pid, :get_results, :infinity)
  end

  @doc """
  Gets the current dataset items from the running actor.
  Returns immediately with whatever items are available.
  """
  def get_current_dataset_items(pid) do
    GenServer.call(pid, :get_current_dataset_items)
  end

  @doc """
  Subscribe to receive updates about the run status.
  The subscriber will receive messages like:
  - `{:actor_run_started, run_id}`
  - `{:actor_run_update, run_id, status}`
  - `{:actor_run_dataset_update, run_id, items}` (when new dataset items are available)
  - `{:actor_run_complete, run_id, results}`
  - `{:actor_run_failed, run_id, error}`
  - `{:actor_run_timeout, run_id}`
  - `{:actor_run_aborted, run_id}`
  """
  def subscribe(pid) do
    GenServer.call(pid, :subscribe)
  end

  @doc """
  Abort the actor run.
  """
  def abort(pid) do
    GenServer.call(pid, :abort)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    actor_id = Keyword.fetch!(opts, :actor_id)
    input = Keyword.fetch!(opts, :input)
    token = Keyword.get(opts, :token) || System.get_env("APIFY_TOKEN")

    if is_nil(token) do
      {:stop, {:error, :no_token}}
    else
      client = ApifyClient.new(token: token)

      state = %__MODULE__{
        client: client,
        actor_id: actor_id,
        poll_attempts: 0,
        status: :initializing,
        subscribers: []
      }

      # Start the actor run asynchronously
      send(self(), {:start_actor, input})

      {:ok, state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status_info = %{
      actor_id: state.actor_id,
      run_id: state.run_id,
      status: state.status,
      started_at: state.started_at,
      finished_at: state.finished_at,
      stats: state.stats,
      error: state.error
    }

    {:reply, status_info, state}
  end

  @impl true
  def handle_call(:get_results, _from, %{status: :succeeded, dataset_items: items} = state)
      when not is_nil(items) do
    {:reply, {:ok, items}, state}
  end

  @impl true
  def handle_call(:get_results, _from, %{status: :failed, error: error} = state) do
    {:reply, {:error, error}, state}
  end

  @impl true
  def handle_call(:get_results, from, state) do
    # Run is not complete, wait for it
    Process.send_after(self(), {:check_results, from}, 1000)
    {:noreply, state}
  end

  @impl true
  def handle_call(:subscribe, {pid, _ref}, state) do
    {:reply, :ok, %{state | subscribers: [pid | state.subscribers]}}
  end

  @impl true
  def handle_call(:get_current_dataset_items, _from, state) do
    if state.dataset_client do
      case Dataset.list_items(state.dataset_client) do
        {:ok, items} ->
          {:reply, {:ok, items}, %{state | dataset_items: items}}

        {:error, error} ->
          {:reply, {:error, error}, state}
      end
    else
      {:reply, {:error, :no_dataset}, state}
    end
  end

  @impl true
  def handle_call(:abort, _from, state) do
    result =
      if state.run_client do
        Run.abort(state.run_client)
      else
        {:error, :no_run}
      end

    {:reply, result, %{state | status: :aborting}}
  end

  @impl true
  def handle_info({:start_actor, input}, state) do
    Logger.info("Starting actor #{state.actor_id}")

    actor_client = Actor.new(state.client, state.actor_id)

    case Actor.call(actor_client, input, %{}) do
      {:ok, run_info} ->
        run_id = run_info["id"]
        run_client = ApifyClient.run(state.client, run_id)

        # Create dataset client if available
        dataset_client =
          if run_info["defaultDatasetId"] do
            ApifyClient.dataset(state.client, run_info["defaultDatasetId"])
          else
            nil
          end

        Logger.info("Actor started with run ID: #{run_id}")

        new_state = %{
          state
          | run_id: run_id,
            run_client: run_client,
            dataset_client: dataset_client,
            status: :running,
            started_at: DateTime.utc_now()
        }

        # Start polling for status
        Process.send_after(self(), :poll_status, @poll_interval)

        notify_subscribers(new_state, {:actor_run_started, run_id})

        {:noreply, new_state}

      {:error, error} ->
        Logger.error("Failed to start actor: #{inspect(error)}")

        new_state = %{state | status: :failed, error: error}

        notify_subscribers(new_state, {:actor_run_failed, nil, error})

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:poll_status, %{poll_attempts: attempts} = state)
      when attempts >= @max_poll_attempts do
    Logger.error("Max poll attempts reached for run #{state.run_id}")

    new_state = %{state | status: :timeout, error: :max_poll_attempts_reached}

    notify_subscribers(new_state, {:actor_run_timeout, state.run_id})

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:poll_status, state) do
    case Run.get(state.run_client) do
      {:ok, run_info} ->
        status = run_status_to_atom(run_info["status"])

        new_state = %{
          state
          | status: status,
            poll_attempts: state.poll_attempts + 1,
            stats: extract_stats(run_info)
        }

        case status do
          :succeeded ->
            Logger.info("Run #{state.run_id} succeeded")
            handle_success(new_state, run_info)

          :failed ->
            Logger.error("Run #{state.run_id} failed")
            handle_failure(new_state, run_info)

          :aborted ->
            Logger.info("Run #{state.run_id} was aborted")
            handle_aborted(new_state, run_info)

          status when status in [:running, :ready] ->
            # Fetch current dataset items and notify if new items found
            updated_state =
              if new_state.dataset_client do
                case Dataset.list_items(new_state.dataset_client) do
                  {:ok, items} ->
                    if items != new_state.dataset_items and length(items) > 0 do
                      notify_subscribers(
                        new_state,
                        {:actor_run_dataset_update, state.run_id, items}
                      )
                    end

                    %{new_state | dataset_items: items}

                  {:error, _} ->
                    new_state
                end
              else
                new_state
              end

            # Continue polling
            Process.send_after(self(), :poll_status, @poll_interval)

            if status != state.status do
              notify_subscribers(updated_state, {:actor_run_update, state.run_id, status})
            end

            {:noreply, updated_state}

          _ ->
            # Unknown status, continue polling but log it
            Logger.warning("Unknown run status: #{run_info["status"]}")
            Process.send_after(self(), :poll_status, @poll_interval)
            {:noreply, new_state}
        end

      {:error, error} ->
        Logger.error("Failed to poll run status: #{inspect(error)}")

        # Retry polling after a delay
        Process.send_after(self(), :poll_status, @poll_interval * 2)

        {:noreply, %{state | poll_attempts: state.poll_attempts + 1}}
    end
  end

  @impl true
  def handle_info({:check_results, from}, state) do
    # Check if results are ready now
    if state.status == :succeeded && state.dataset_items do
      GenServer.reply(from, {:ok, state.dataset_items})
    else
      if state.status == :failed do
        GenServer.reply(from, {:error, state.error})
      else
        # Keep waiting
        Process.send_after(self(), {:check_results, from}, 1000)
      end
    end

    {:noreply, state}
  end

  # Private Functions

  defp handle_success(state, _run_info) do
    finished_state = %{state | finished_at: DateTime.utc_now()}

    # Fetch final dataset items if available
    if state.dataset_client do
      case Dataset.list_items(state.dataset_client) do
        {:ok, items} ->
          final_state = %{finished_state | dataset_items: items}
          notify_subscribers(final_state, {:actor_run_complete, state.run_id, items})
          {:noreply, final_state}

        {:error, error} ->
          Logger.error("Failed to fetch dataset items: #{inspect(error)}")
          # Use previously fetched items if available
          items = state.dataset_items || []
          final_state = %{finished_state | dataset_items: items}
          notify_subscribers(final_state, {:actor_run_complete, state.run_id, items})
          {:noreply, final_state}
      end
    else
      # Use previously fetched items if available
      items = state.dataset_items || []
      final_state = %{finished_state | dataset_items: items}
      notify_subscribers(final_state, {:actor_run_complete, state.run_id, items})
      {:noreply, final_state}
    end
  end

  defp handle_failure(state, run_info) do
    error = run_info["exitCode"] || run_info["error"] || "Unknown error"

    final_state = %{state | finished_at: DateTime.utc_now(), error: error}

    notify_subscribers(final_state, {:actor_run_failed, state.run_id, error})

    {:noreply, final_state}
  end

  defp handle_aborted(state, _run_info) do
    final_state = %{state | finished_at: DateTime.utc_now()}

    notify_subscribers(final_state, {:actor_run_aborted, state.run_id})

    {:noreply, final_state}
  end

  defp run_status_to_atom(status) do
    case status do
      "READY" -> :ready
      "RUNNING" -> :running
      "SUCCEEDED" -> :succeeded
      "FAILED" -> :failed
      "TIMING-OUT" -> :timing_out
      "TIMED-OUT" -> :timed_out
      "ABORTING" -> :aborting
      "ABORTED" -> :aborted
      _ -> :unknown
    end
  end

  defp extract_stats(run_info) do
    %{
      compute_units: run_info["stats"]["computeUnits"],
      dataset_items: run_info["stats"]["datasetItemCount"],
      request_retries: run_info["stats"]["requestRetries"],
      request_failed: run_info["stats"]["requestFailed"],
      runtime_secs: run_info["stats"]["runTimeSecs"],
      memory_avg_mb:
        run_info["stats"]["memAvgBytes"] &&
          run_info["stats"]["memAvgBytes"] / 1024 / 1024,
      memory_max_mb:
        run_info["stats"]["memMaxBytes"] &&
          run_info["stats"]["memMaxBytes"] / 1024 / 1024
    }
  rescue
    _ -> %{}
  end

  defp notify_subscribers(state, message) do
    Enum.each(state.subscribers, fn pid ->
      if Process.alive?(pid) do
        send(pid, message)
      end
    end)
  end
end
