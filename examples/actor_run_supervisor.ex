defmodule ApifyClient.Examples.ActorRunSupervisor do
  @moduledoc """
  Example supervisor for managing multiple actor run monitors.

  This demonstrates how to:
  - Supervise multiple actor runs
  - Handle crashes and restarts
  - Coordinate between multiple runs
  - Aggregate results from multiple actors

  ## Usage

      # Start the supervisor
      {:ok, sup} = ApifyClient.Examples.ActorRunSupervisor.start_link(
        token: "your_apify_token"
      )

      # Start monitoring a web scraper run
      {:ok, monitor_pid} = ApifyClient.Examples.ActorRunSupervisor.start_monitor(sup,
        actor_id: "apify/web-scraper",
        input: %{
          startUrls: [%{url: "https://example.com"}],
          maxPagesPerCrawl: 5
        }
      )

      # Start multiple monitors for parallel scraping
      urls = ["https://example1.com", "https://example2.com", "https://example3.com"]

      monitors = Enum.map(urls, fn url ->
        {:ok, pid} = ApifyClient.Examples.ActorRunSupervisor.start_monitor(sup,
          actor_id: "apify/web-scraper",
          input: %{startUrls: [%{url: url}], maxPagesPerCrawl: 1}
        )
        pid
      end)

      # Wait for all to complete and collect results
      results = ApifyClient.Examples.ActorRunSupervisor.collect_all_results(monitors)
  """

  use DynamicSupervisor
  require Logger

  alias ApifyClient.Examples.ActorRunMonitor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [opts])
  end

  @doc """
  Starts a new actor run monitor under supervision.
  """
  def start_monitor(supervisor \\ __MODULE__, opts) do
    spec = {ActorRunMonitor, opts}
    DynamicSupervisor.start_child(supervisor, spec)
  end

  @doc """
  Collects results from multiple monitors, waiting for all to complete.
  """
  def collect_all_results(monitor_pids, timeout \\ 60_000) do
    monitor_pids
    |> Enum.map(fn pid ->
      Task.async(fn ->
        try do
          ActorRunMonitor.get_results(pid)
        catch
          :exit, _ -> {:error, :monitor_died}
        end
      end)
    end)
    |> Task.await_many(timeout)
  end

  @doc """
  Stops all running monitors.
  """
  def stop_all_monitors(supervisor \\ __MODULE__) do
    children = DynamicSupervisor.which_children(supervisor)

    Enum.each(children, fn {_, pid, _, _} ->
      DynamicSupervisor.terminate_child(supervisor, pid)
    end)
  end

  @doc """
  Returns the status of all running monitors.
  """
  def get_all_statuses(supervisor \\ __MODULE__) do
    supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} ->
      try do
        ActorRunMonitor.get_status(pid)
      catch
        :exit, _ -> %{status: :dead, pid: pid}
      end
    end)
  end
end

defmodule ApifyClient.Examples.ScrapingOrchestrator do
  @moduledoc """
  Example of a more complex scraping orchestrator that coordinates
  multiple actor runs with different strategies.

  This example shows how to:
  - Run actors in parallel
  - Chain actor outputs as inputs to other actors
  - Handle retries and failures
  - Aggregate and process results
  """

  use GenServer
  require Logger

  alias ApifyClient.Examples.{ActorRunMonitor, ActorRunSupervisor}

  defstruct [
    :client,
    :supervisor,
    jobs: %{},
    results: %{},
    subscribers: []
  ]

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Scrapes multiple URLs in parallel using the same actor configuration.
  """
  def parallel_scrape(urls, actor_id \\ "apify/web-scraper", config \\ %{}) do
    GenServer.call(__MODULE__, {:parallel_scrape, urls, actor_id, config}, :infinity)
  end

  @doc """
  Runs a pipeline of actors where each actor's output feeds into the next.
  """
  def run_pipeline(pipeline) do
    GenServer.call(__MODULE__, {:run_pipeline, pipeline}, :infinity)
  end

  @doc """
  Scrapes URLs with automatic retry on failure.
  """
  def scrape_with_retry(url, max_retries \\ 3) do
    GenServer.call(__MODULE__, {:scrape_with_retry, url, max_retries}, :infinity)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    token = Keyword.get(opts, :token) || System.get_env("APIFY_TOKEN")
    client = ApifyClient.new(token: token)

    # Start the supervisor for actor monitors
    {:ok, supervisor} = ActorRunSupervisor.start_link(token: token)

    {:ok,
     %__MODULE__{
       client: client,
       supervisor: supervisor,
       jobs: %{},
       results: %{},
       subscribers: []
     }}
  end

  @impl true
  def handle_call({:parallel_scrape, urls, actor_id, config}, from, state) do
    job_id = generate_job_id()

    # Start monitors for each URL
    monitors =
      Enum.map(urls, fn url ->
        input =
          Map.merge(config, %{
            startUrls: [%{url: url}],
            maxPagesPerCrawl: Map.get(config, :maxPagesPerCrawl, 1)
          })

        {:ok, pid} =
          ActorRunSupervisor.start_monitor(state.supervisor,
            actor_id: actor_id,
            input: input,
            token: state.client.config.token
          )

        # Subscribe to updates
        ActorRunMonitor.subscribe(pid)

        {url, pid}
      end)

    # Store job info
    new_state = %{
      state
      | jobs:
          Map.put(state.jobs, job_id, %{
            type: :parallel_scrape,
            monitors: monitors,
            from: from,
            completed: [],
            failed: []
          })
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:run_pipeline, pipeline}, from, state) do
    job_id = generate_job_id()

    # Start the first actor in the pipeline
    Task.start(fn ->
      run_pipeline_step(pipeline, 0, [], state, job_id, from)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call({:scrape_with_retry, url, max_retries}, from, state) do
    job_id = generate_job_id()

    Task.start(fn ->
      retry_scrape(url, max_retries, 0, state, job_id, from)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:actor_run_complete, run_id, results}, state) do
    # Find which job this run belongs to
    updated_jobs =
      Enum.map(state.jobs, fn {job_id, job} ->
        case find_monitor_in_job(job, run_id) do
          {url, _pid} ->
            completed = [{url, results} | job.completed]

            # Check if all monitors are complete
            if length(completed) + length(job.failed) == length(job.monitors) do
              # Job complete, send response
              GenServer.reply(
                job.from,
                {:ok,
                 %{
                   completed: completed,
                   failed: job.failed
                 }}
              )

              # Mark for removal
              {job_id, nil}
            else
              {job_id, %{job | completed: completed}}
            end

          nil ->
            {job_id, job}
        end
      end)
      |> Enum.reject(fn {_, job} -> is_nil(job) end)
      |> Map.new()

    {:noreply, %{state | jobs: updated_jobs}}
  end

  @impl true
  def handle_info({:actor_run_failed, run_id, error}, state) do
    # Handle failed runs
    updated_jobs =
      Enum.map(state.jobs, fn {job_id, job} ->
        case find_monitor_in_job(job, run_id) do
          {url, _pid} ->
            failed = [{url, error} | job.failed]

            # Check if all monitors are complete
            if length(job.completed) + length(failed) == length(job.monitors) do
              # Job complete, send response
              GenServer.reply(
                job.from,
                {:ok,
                 %{
                   completed: job.completed,
                   failed: failed
                 }}
              )

              # Mark for removal
              {job_id, nil}
            else
              {job_id, %{job | failed: failed}}
            end

          nil ->
            {job_id, job}
        end
      end)
      |> Enum.reject(fn {_, job} -> is_nil(job) end)
      |> Map.new()

    {:noreply, %{state | jobs: updated_jobs}}
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end

  # Private Functions

  defp run_pipeline_step([], _step, results, _state, _job_id, from) do
    GenServer.reply(from, {:ok, results})
  end

  defp run_pipeline_step(
         [{actor_id, transform_fn} | rest],
         step,
         prev_results,
         state,
         job_id,
         from
       ) do
    # Transform previous results into input for next actor
    input = transform_fn.(prev_results)

    {:ok, pid} =
      ActorRunSupervisor.start_monitor(state.supervisor,
        actor_id: actor_id,
        input: input,
        token: state.client.config.token
      )

    # Wait for results
    case ActorRunMonitor.get_results(pid) do
      {:ok, results} ->
        run_pipeline_step(rest, step + 1, results, state, job_id, from)

      {:error, error} ->
        GenServer.reply(from, {:error, {:pipeline_failed, step, error}})
    end
  end

  defp retry_scrape(_url, max_retries, attempt, _state, _job_id, from)
       when attempt >= max_retries do
    GenServer.reply(from, {:error, :max_retries_exceeded})
  end

  defp retry_scrape(url, max_retries, attempt, state, job_id, from) do
    {:ok, pid} =
      ActorRunSupervisor.start_monitor(state.supervisor,
        actor_id: "apify/web-scraper",
        input: %{
          startUrls: [%{url: url}],
          maxPagesPerCrawl: 1
        },
        token: state.client.config.token
      )

    case ActorRunMonitor.get_results(pid) do
      {:ok, results} ->
        GenServer.reply(from, {:ok, results})

      {:error, _error} ->
        Logger.warning("Scrape attempt #{attempt + 1} failed for #{url}, retrying...")
        # Exponential backoff
        Process.sleep(2000 * (attempt + 1))
        retry_scrape(url, max_retries, attempt + 1, state, job_id, from)
    end
  end

  defp find_monitor_in_job(job, run_id) do
    Enum.find(job.monitors, fn {_url, pid} ->
      case ActorRunMonitor.get_status(pid) do
        %{run_id: ^run_id} -> true
        _ -> false
      end
    end)
  catch
    :exit, _ -> nil
  end

  defp generate_job_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end
end
