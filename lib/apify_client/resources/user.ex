defmodule ApifyClient.Resources.User do
  @moduledoc """
  Client for managing user information.

  Provides methods for getting user details and monthly usage statistics.
  """

  use ApifyClient.Base.ResourceClient, resource_path: "users"

  @doc """
  Gets user information.

  For the current user, use "me" as the user ID.

  ## Examples

      iex> user |> User.get()
      {:ok, %{"id" => "user_id", "username" => "john", ...}}
  """
  def get(user) do
    super(user)
  end

  @doc """
  Gets monthly usage statistics for the user.

  Returns detailed usage information including data transfer, compute units, and storage usage.

  ## Parameters

    * `options` - Usage query options

  ## Options

    * `:date` - Month to get usage for (format: "YYYY-MM", default: current month)

  ## Examples

      iex> user |> User.monthly_usage()
      {:ok, %{"dataTransfer" => %{"totalBytes" => 1000000}, ...}}

      iex> user |> User.monthly_usage(date: "2023-12")
      {:ok, %{"dataTransfer" => %{"totalBytes" => 2000000}, ...}}
  """
  @spec monthly_usage(t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def monthly_usage(user, options \\ []) do
    params = build_usage_params(options)

    HTTPClient.get(
      user.http_client,
      url(user, "usage/monthly"),
      params: params
    )
  end

  @doc """
  Gets usage limits for the user.

  Returns information about the user's plan limits and current usage.

  ## Examples

      iex> user |> User.limits()
      {:ok, %{"monthlyUsage" => %{...}, "limits" => %{...}}}
  """
  @spec limits(t()) :: {:ok, map()} | {:error, Error.t()}
  def limits(user) do
    HTTPClient.get(user.http_client, url(user, "limits"))
  end

  # Private helper functions

  defp build_usage_params(options) do
    options
    |> Keyword.take([:date])
    |> Enum.reduce(%{}, fn
      {:date, date}, acc ->
        Map.put(acc, "date", date)

      _, acc ->
        acc
    end)
  end
end
