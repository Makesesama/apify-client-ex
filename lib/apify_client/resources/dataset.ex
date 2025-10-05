defmodule ApifyClient.Resources.Dataset do
  @moduledoc """
  Client for managing a specific dataset.

  Provides methods for getting dataset information, downloading items, and managing dataset data.
  """

  use ApifyClient.Base.ResourceClient, resource_path: "datasets"

  @type list_items_options :: %{
          optional(:offset) => non_neg_integer(),
          optional(:limit) => non_neg_integer(),
          optional(:desc) => boolean(),
          optional(:fields) => [String.t()],
          optional(:omit) => [String.t()],
          optional(:unwind) => String.t(),
          optional(:skip_empty) => boolean(),
          optional(:skip_hidden) => boolean(),
          optional(:clean) => boolean(),
          optional(:format) => String.t(),
          optional(:view) => String.t(),
          optional(:simplified) => boolean()
        }

  @type push_items_options :: %{
          optional(:content_type) => String.t()
        }

  @doc """
  Lists dataset items.

  ## Options

    * `:offset` - Number of items to skip (default: 0)
    * `:limit` - Maximum number of items to return
    * `:desc` - If true, sorts in descending order (default: false)
    * `:fields` - Fields to include in the response
    * `:omit` - Fields to omit from the response
    * `:unwind` - Field to unwind
    * `:skip_empty` - Skip empty items (default: false)
    * `:skip_hidden` - Skip hidden fields (default: false)
    * `:clean` - Clean the data (default: false)
    * `:format` - Output format ("json", "csv", "xlsx", "html", "xml", "rss")
    * `:view` - Dataset view to use
    * `:simplified` - Use simplified format (default: false)

  ## Examples

      iex> dataset |> Dataset.list_items()
      {:ok, [...]}

      iex> dataset |> Dataset.list_items(limit: 100, format: "csv")
      {:ok, "csv,data\\n..."}
  """
  @spec list_items(t(), list_items_options()) :: {:ok, any()} | {:error, Error.t()}
  def list_items(dataset, options \\ %{}) do
    params = build_list_items_params(options)
    HTTPClient.get(dataset.http_client, url(dataset, "items"), params: params)
  end

  @doc """
  Downloads dataset items as a stream.

  Returns a stream that yields items as they are downloaded.

  ## Options

  Same as `list_items/2`.

  ## Examples

      iex> {:ok, stream} = dataset |> Dataset.stream_items()
      iex> stream |> Enum.take(10)
      [%{...}, %{...}, ...]
  """
  @spec stream_items(t(), list_items_options()) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def stream_items(dataset, options \\ %{}) do
    params = build_list_items_params(options)
    HTTPClient.stream(dataset.http_client, url(dataset, "items"), params: params)
  end

  @doc """
  Downloads the dataset items to a file.

  ## Parameters

    * `file_path` - Path where to save the file
    * `options` - Download options (same as `list_items/2`)

  ## Examples

      iex> dataset |> Dataset.download_items("/tmp/data.json")
      :ok

      iex> dataset |> Dataset.download_items("/tmp/data.csv", format: "csv")
      :ok
  """
  @spec download_items(t(), String.t(), list_items_options()) :: :ok | {:error, Error.t()}
  def download_items(dataset, file_path, options \\ %{}) do
    case stream_items(dataset, options) do
      {:ok, stream} ->
        try do
          stream
          |> Stream.into(File.stream!(file_path))
          |> Stream.run()

          :ok
        rescue
          e -> {:error, Error.new(:file_error, Exception.message(e))}
        end
    end
  end

  @doc """
  Gets a specific item from the dataset.

  ## Parameters

    * `item_id` - ID of the item to retrieve

  ## Examples

      iex> dataset |> Dataset.get_item("item123")
      {:ok, %{...}}
  """
  @spec get_item(t(), String.t()) :: {:ok, map() | nil} | {:error, Error.t()}
  def get_item(dataset, item_id) do
    HTTPClient.get(dataset.http_client, url(dataset, "items/#{URI.encode_www_form(item_id)}"))
  end

  @doc """
  Pushes items to the dataset.

  ## Parameters

    * `items` - Items to push (can be a single item or a list of items)
    * `options` - Push options

  ## Options

    * `:content_type` - Content type of the items (default: "application/json")

  ## Examples

      iex> dataset |> Dataset.push_items([%{name: "John", age: 30}])
      {:ok, nil}

      iex> dataset |> Dataset.push_items(%{name: "Jane", age: 25})
      {:ok, nil}
  """
  @spec push_items(t(), any(), push_items_options()) :: {:ok, nil} | {:error, Error.t()}
  def push_items(dataset, items, options \\ %{}) do
    content_type = Map.get(options, :content_type, "application/json")

    HTTPClient.post(
      dataset.http_client,
      url(dataset, "items"),
      items,
      content_type: content_type
    )
  end

  @doc """
  Pushes a single item to the dataset.

  This is a convenience method that calls `push_items/3` with a single item.

  ## Examples

      iex> dataset |> Dataset.push_item(%{name: "John", age: 30})
      {:ok, nil}
  """
  @spec push_item(t(), any(), push_items_options()) :: {:ok, nil} | {:error, Error.t()}
  def push_item(dataset, item, options \\ %{}) do
    push_items(dataset, item, options)
  end

  @doc """
  Deletes the dataset.

  ## Examples

      iex> dataset |> Dataset.delete()
      {:ok, nil}
  """
  def delete(dataset) do
    super(dataset)
  end

  # Private helper functions

  defp build_list_items_params(options) do
    # Convert keyword list to map if needed
    options_map = if is_list(options), do: Map.new(options), else: options

    options_map
    |> Map.take([
      :offset,
      :limit,
      :desc,
      :fields,
      :omit,
      :unwind,
      :skip_empty,
      :skip_hidden,
      :clean,
      :format,
      :view,
      :simplified
    ])
    |> Enum.reduce(%{}, fn
      {:fields, fields}, acc when is_list(fields) ->
        Map.put(acc, "fields", Enum.join(fields, ","))

      {:omit, fields}, acc when is_list(fields) ->
        Map.put(acc, "omit", Enum.join(fields, ","))

      {:desc, true}, acc ->
        Map.put(acc, "desc", 1)

      {:desc, false}, acc ->
        Map.put(acc, "desc", 0)

      {key, true}, acc when key in [:skip_empty, :skip_hidden, :clean, :simplified] ->
        Map.put(acc, Atom.to_string(key), 1)

      {key, false}, acc when key in [:skip_empty, :skip_hidden, :clean, :simplified] ->
        Map.put(acc, Atom.to_string(key), 0)

      {key, value}, acc ->
        Map.put(acc, Atom.to_string(key), value)
    end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
