defmodule ApifyClient.Resources.Actor do
  @moduledoc """
  Client for managing a specific actor.

  Provides methods for getting actor details, running actors, and managing builds, runs, and versions.
  """

  use ApifyClient.Base.ResourceClient, resource_path: "acts"

  alias ApifyClient.Resources.{
    ActorVersionCollection,
    BuildCollection,
    RunCollection,
    WebhookCollection
  }

  # Override safe_id to handle actor-specific ID encoding (slash to tilde)
  def safe_id(id) when is_binary(id) do
    # For actors, convert slash to tilde as per API docs
    String.replace(id, "/", "~")
  end

  @type call_options :: %{
          optional(:build) => String.t(),
          optional(:content_type) => String.t(),
          optional(:memory) => pos_integer(),
          optional(:timeout) => pos_integer(),
          optional(:wait_for_finish) => pos_integer(),
          optional(:webhooks) => [map()],
          optional(:max_items) => non_neg_integer(),
          optional(:max_total_charge_usd) => number()
        }

  @doc """
  Starts the actor and immediately returns the run information.

  ## Parameters

    * `input` - Input data for the actor (can be any JSON-serializable data)
    * `options` - Call options

  ## Options

    * `:build` - Tag or number of the actor build to run (default: latest)
    * `:content_type` - Content type of the input (default: "application/json")
    * `:memory` - Memory limit for the actor run in megabytes
    * `:timeout` - Timeout for the actor run in seconds
    * `:wait_for_finish` - Time to wait for the run to finish in seconds
    * `:webhooks` - List of webhook definitions
    * `:max_items` - Maximum number of items that the actor run should produce
    * `:max_total_charge_usd` - Maximum total charge for the run in USD

  ## Examples

      iex> actor |> Actor.call(%{startUrls: [%{url: "https://example.com"}]})
      {:ok, %{"id" => "run_id", ...}}

      iex> actor |> Actor.call(input, memory: 512, timeout: 300)
      {:ok, %{"id" => "run_id", ...}}
  """
  @spec call(t(), any(), call_options()) :: {:ok, map()} | {:error, Error.t()}
  def call(actor, input, options \\ %{}) do
    params = build_call_params(options)
    opts = build_call_opts(options)

    HTTPClient.post(
      actor.http_client,
      url(actor, "runs"),
      input,
      [params: params] ++ opts
    )
  end

  @doc """
  Starts the actor and waits for it to finish, then returns the run information.

  This is a convenience method that combines `call/3` with polling for completion.

  ## Parameters

    * `input` - Input data for the actor
    * `options` - Call options (same as `call/3`)

  ## Examples

      iex> actor |> Actor.start(%{startUrls: [%{url: "https://example.com"}]})
      {:ok, %{"id" => "run_id", "status" => "SUCCEEDED", ...}}
  """
  @spec start(t(), any(), call_options()) :: {:ok, map()} | {:error, Error.t()}
  def start(actor, input, options \\ %{}) do
    # Add wait_for_finish if not specified
    options_with_wait = Map.put_new(options, :wait_for_finish, 60)
    call(actor, input, options_with_wait)
  end

  @doc """
  Returns a client for the actor's runs.

  ## Examples

      iex> actor |> Actor.runs()
      %ApifyClient.Resources.RunCollection{...}
  """
  @spec runs(t()) :: RunCollection.t()
  def runs(actor) do
    RunCollection.new(actor.client, actor_id: actor.id)
  end

  @doc """
  Returns a client for the actor's builds.

  ## Examples

      iex> actor |> Actor.builds()
      %ApifyClient.Resources.BuildCollection{...}
  """
  @spec builds(t()) :: BuildCollection.t()
  def builds(actor) do
    BuildCollection.new(actor.client, actor_id: actor.id)
  end

  @doc """
  Returns a client for the actor's versions.

  ## Examples

      iex> actor |> Actor.versions()
      %ApifyClient.Resources.ActorVersionCollection{...}
  """
  @spec versions(t()) :: ActorVersionCollection.t()
  def versions(actor) do
    ActorVersionCollection.new(actor.client, actor_id: actor.id)
  end

  @doc """
  Returns a client for the actor's webhooks.

  ## Examples

      iex> actor |> Actor.webhooks()
      %ApifyClient.Resources.WebhookCollection{...}
  """
  @spec webhooks(t()) :: WebhookCollection.t()
  def webhooks(actor) do
    WebhookCollection.new(actor.client, actor_id: actor.id)
  end

  @doc """
  Builds the actor.

  ## Parameters

    * `options` - Build options

  ## Options

    * `:version_number` - Actor version number to build
    * `:beta_packages` - Use beta packages
    * `:tag` - Tag for the build
    * `:use_cache` - Use cache for the build
    * `:wait_for_finish` - Time to wait for the build to finish in seconds

  ## Examples

      iex> actor |> Actor.build()
      {:ok, %{"id" => "build_id", ...}}

      iex> actor |> Actor.build(version_number: "1.0", wait_for_finish: 120)
      {:ok, %{"id" => "build_id", ...}}
  """
  @spec build(t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def build(actor, options \\ %{}) do
    params = build_build_params(options)

    HTTPClient.post(
      actor.http_client,
      url(actor, "builds"),
      %{},
      params: params
    )
  end

  # Private helper functions

  defp build_call_params(options) do
    # Convert keyword list to map if needed
    options_map = if is_list(options), do: Map.new(options), else: options

    options_map
    |> Map.take([:build, :memory, :timeout, :wait_for_finish, :max_items, :max_total_charge_usd])
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
    |> Map.put("webhooks", encode_webhooks(options_map[:webhooks]))
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp build_call_opts(options) do
    # Convert keyword list to map if needed
    options_map = if is_list(options), do: Map.new(options), else: options

    case options_map[:content_type] do
      nil -> []
      content_type -> [content_type: content_type]
    end
  end

  defp encode_webhooks(nil), do: nil
  defp encode_webhooks([]), do: nil

  defp encode_webhooks(webhooks) when is_list(webhooks) do
    webhooks
    |> Jason.encode!()
    |> Base.encode64()
  end

  defp build_build_params(options) do
    options
    |> Map.take([:version_number, :beta_packages, :tag, :use_cache, :wait_for_finish])
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
