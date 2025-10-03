defmodule ApifyClient.Resources.Run do
  @moduledoc """
  Client for managing a specific actor run.
  """

  use ApifyClient.Base.ResourceClient, resource_path: "runs"

  alias ApifyClient.Resources.{Dataset, KeyValueStore, Log, RequestQueue}

  @doc """
  Aborts the run.
  """
  @spec abort(t()) :: {:ok, map()} | {:error, Error.t()}
  def abort(run) do
    HTTPClient.post(run.http_client, url(run, "abort"), %{})
  end

  @doc """
  Metamorphs the run into another actor run.
  """
  @spec metamorph(t(), String.t(), any(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def metamorph(run, target_actor_id, input, opts \\ []) do
    params = build_params(opts)

    HTTPClient.post(
      run.http_client,
      url(run, "metamorph"),
      %{targetActorId: target_actor_id, input: input},
      params: params
    )
  end

  @doc """
  Waits for the run to finish and returns the final state.
  """
  @spec wait_for_finish(t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def wait_for_finish(run, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms, 60_000)
    poll_interval_ms = Keyword.get(opts, :poll_interval_ms, 1_000)

    wait_for_finish_loop(run, timeout_ms, poll_interval_ms, System.monotonic_time(:millisecond))
  end

  @doc """
  Returns a client for accessing the run's log.

  ## Examples

      iex> run |> Run.log()
      %ApifyClient.Resources.Log{...}
  """
  @spec log(t()) :: Log.t()
  def log(run) do
    Log.new(run.client, run.id)
  end

  @doc """
  Returns a client for the default dataset of this run.

  ## Examples

      iex> run |> Run.dataset()
      %ApifyClient.Resources.Dataset{...}
  """
  @spec dataset(t()) :: Dataset.t()
  def dataset(run) do
    case get(run) do
      {:ok, %{"defaultDatasetId" => dataset_id}} when not is_nil(dataset_id) ->
        Dataset.new(run.client, dataset_id)

      _ ->
        # Return a dataset client without ID - will fail on operations
        Dataset.new(run.client, nil)
    end
  end

  @doc """
  Returns a client for the default key-value store of this run.

  ## Examples

      iex> run |> Run.key_value_store()
      %ApifyClient.Resources.KeyValueStore{...}
  """
  @spec key_value_store(t()) :: KeyValueStore.t()
  def key_value_store(run) do
    case get(run) do
      {:ok, %{"defaultKeyValueStoreId" => store_id}} when not is_nil(store_id) ->
        KeyValueStore.new(run.client, store_id)

      _ ->
        # Return a store client without ID - will fail on operations
        KeyValueStore.new(run.client, nil)
    end
  end

  @doc """
  Returns a client for the default request queue of this run.

  ## Examples

      iex> run |> Run.request_queue()
      %ApifyClient.Resources.RequestQueue{...}
  """
  @spec request_queue(t()) :: RequestQueue.t()
  def request_queue(run) do
    case get(run) do
      {:ok, %{"defaultRequestQueueId" => queue_id}} when not is_nil(queue_id) ->
        RequestQueue.new(run.client, queue_id)

      _ ->
        # Return a queue client without ID - will fail on operations
        RequestQueue.new(run.client, nil)
    end
  end

  defp wait_for_finish_loop(run, timeout_ms, poll_interval_ms, start_time) do
    case get(run) do
      {:ok, %{"status" => status} = run_data}
      when status in ["SUCCEEDED", "FAILED", "ABORTED", "TIMED-OUT"] ->
        {:ok, run_data}

      {:ok, _run_data} ->
        current_time = System.monotonic_time(:millisecond)

        if current_time - start_time > timeout_ms do
          {:error, Error.new(:timeout_error, "Run did not finish within timeout")}
        else
          Process.sleep(poll_interval_ms)
          wait_for_finish_loop(run, timeout_ms, poll_interval_ms, start_time)
        end

      {:error, _} = error ->
        error
    end
  end
end
