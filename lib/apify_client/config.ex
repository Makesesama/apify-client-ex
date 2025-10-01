defmodule ApifyClient.Config do
  @moduledoc """
  Configuration for the Apify API client.
  """

  @type t :: %__MODULE__{
          token: String.t() | nil,
          base_url: String.t(),
          public_base_url: String.t(),
          max_retries: non_neg_integer(),
          min_delay_between_retries_ms: non_neg_integer(),
          timeout_ms: non_neg_integer(),
          user_agent_suffix: String.t() | nil
        }

  @enforce_keys [
    :base_url,
    :public_base_url,
    :max_retries,
    :min_delay_between_retries_ms,
    :timeout_ms
  ]
  defstruct [
    :token,
    :base_url,
    :public_base_url,
    :max_retries,
    :min_delay_between_retries_ms,
    :timeout_ms,
    :user_agent_suffix
  ]

  @default_base_url "https://api.apify.com"
  @default_timeout_ms 360_000
  @default_max_retries 8
  @default_min_delay_between_retries_ms 500

  @doc """
  Creates a new configuration struct.

  ## Options

    * `:token` - Your Apify API token (optional, can also be set via APIFY_TOKEN env var)
    * `:base_url` - Base URL for the API (default: "https://api.apify.com")
    * `:public_base_url` - Public base URL for the API (default: "https://api.apify.com")
    * `:max_retries` - Maximum number of retries for failed requests (default: 8)
    * `:min_delay_between_retries_ms` - Minimum delay between retries in milliseconds (default: 500)
    * `:timeout_ms` - Request timeout in milliseconds (default: 360_000)
    * `:user_agent_suffix` - Suffix to append to the User-Agent header
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    base_url = opts[:base_url] || @default_base_url
    public_base_url = opts[:public_base_url] || base_url

    %__MODULE__{
      token: opts[:token] || System.get_env("APIFY_TOKEN"),
      base_url: normalize_base_url(base_url),
      public_base_url: normalize_base_url(public_base_url),
      max_retries: opts[:max_retries] || @default_max_retries,
      min_delay_between_retries_ms:
        opts[:min_delay_between_retries_ms] || @default_min_delay_between_retries_ms,
      timeout_ms: opts[:timeout_ms] || @default_timeout_ms,
      user_agent_suffix: opts[:user_agent_suffix]
    }
  end

  @doc """
  Returns the versioned base URL for API calls.
  """
  @spec api_url(t()) :: String.t()
  def api_url(%__MODULE__{base_url: base_url}) do
    "#{base_url}/v2"
  end

  @doc """
  Returns the versioned public base URL.
  """
  @spec public_api_url(t()) :: String.t()
  def public_api_url(%__MODULE__{public_base_url: public_base_url}) do
    "#{public_base_url}/v2"
  end

  defp normalize_base_url(url) do
    String.trim_trailing(url, "/")
  end
end
