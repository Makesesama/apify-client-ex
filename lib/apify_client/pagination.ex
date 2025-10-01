defmodule ApifyClient.Pagination do
  @moduledoc """
  Utilities for handling paginated API responses.

  Provides helpers for working with paginated results from collection endpoints.
  """

  @type paginated_response :: %{
          required(String.t()) => %{
            required(String.t()) => [map()] | non_neg_integer() | boolean()
          }
        }

  @type pagination_options :: %{
          optional(:offset) => non_neg_integer(),
          optional(:limit) => non_neg_integer(),
          optional(:desc) => boolean()
        }

  @doc """
  Extracts items from a paginated response.

  ## Examples

      iex> response = %{"data" => %{"items" => [%{"id" => "1"}], "total" => 1}}
      iex> ApifyClient.Pagination.items(response)
      [%{"id" => "1"}]
  """
  @spec items(paginated_response()) :: [map()]
  def items(%{"data" => %{"items" => items}}), do: items
  def items(_), do: []

  @doc """
  Extracts the total count from a paginated response.

  ## Examples

      iex> response = %{"data" => %{"items" => [], "total" => 100}}
      iex> ApifyClient.Pagination.total(response)
      100
  """
  @spec total(paginated_response()) :: non_neg_integer()
  def total(%{"data" => %{"total" => total}}), do: total
  def total(_), do: 0

  @doc """
  Checks if there are more pages available.

  ## Examples

      iex> response = %{"data" => %{"offset" => 0, "limit" => 10, "total" => 25}}
      iex> ApifyClient.Pagination.has_next_page?(response)
      true

      iex> response = %{"data" => %{"offset" => 20, "limit" => 10, "total" => 25}}
      iex> ApifyClient.Pagination.has_next_page?(response)
      false
  """
  @spec has_next_page?(paginated_response()) :: boolean()
  def has_next_page?(%{"data" => %{"offset" => offset, "limit" => limit, "total" => total}}) do
    offset + limit < total
  end

  def has_next_page?(_), do: false

  @doc """
  Returns options for the next page.

  ## Examples

      iex> response = %{"data" => %{"offset" => 0, "limit" => 10, "total" => 25}}
      iex> ApifyClient.Pagination.next_page_options(response)
      %{offset: 10, limit: 10}
  """
  @spec next_page_options(paginated_response()) :: pagination_options() | nil
  def next_page_options(
        %{"data" => %{"offset" => offset, "limit" => limit, "desc" => desc}} = response
      ) do
    if has_next_page?(response) do
      %{offset: offset + limit, limit: limit, desc: desc}
    else
      nil
    end
  end

  def next_page_options(%{"data" => %{"offset" => offset, "limit" => limit}} = response) do
    if has_next_page?(response) do
      %{offset: offset + limit, limit: limit}
    else
      nil
    end
  end

  def next_page_options(_), do: nil

  @doc """
  Creates a stream that automatically paginates through all results.

  The stream will make API calls as needed to fetch all pages.

  ## Parameters

    * `list_fn` - Function that takes pagination options and returns {:ok, response} or {:error, error}
    * `initial_options` - Initial pagination options

  ## Examples

      iex> list_fn = fn opts -> collection |> Collection.list(opts) end
      iex> stream = ApifyClient.Pagination.stream(list_fn, %{limit: 100})
      iex> all_items = stream |> Enum.to_list()
  """
  @spec stream(
          (pagination_options() -> {:ok, paginated_response()} | {:error, term()}),
          pagination_options()
        ) ::
          Enumerable.t()
  def stream(list_fn, initial_options \\ %{}) do
    Stream.resource(
      fn -> {initial_options, false} end,
      fn
        {_options, true} ->
          {:halt, nil}

        {options, false} ->
          handle_stream_page(list_fn, options)
      end,
      fn _ -> :ok end
    )
    |> Stream.flat_map(& &1)
  catch
    {:pagination_error, error} -> Stream.concat([{:error, error}])
  end

  defp handle_stream_page(list_fn, options) do
    case list_fn.(options) do
      {:ok, response} ->
        items = items(response)

        case next_page_options(response) do
          nil -> {items, {options, true}}
          next_options -> {items, {next_options, false}}
        end

      {:error, error} ->
        throw({:pagination_error, error})
    end
  end

  @doc """
  Collects all items from a paginated endpoint.

  This is a convenience function that uses `stream/2` and collects all results.

  ## Examples

      iex> list_fn = fn opts -> collection |> Collection.list(opts) end
      iex> {:ok, all_items} = ApifyClient.Pagination.all(list_fn, %{limit: 100})
  """
  @spec all(
          (pagination_options() -> {:ok, paginated_response()} | {:error, term()}),
          pagination_options()
        ) ::
          {:ok, [map()]} | {:error, term()}
  def all(list_fn, initial_options \\ %{}) do
    items =
      list_fn
      |> stream(initial_options)
      |> Enum.to_list()

    {:ok, items}
  catch
    {:pagination_error, error} -> {:error, error}
  end
end
