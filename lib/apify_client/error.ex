defmodule ApifyClient.Error do
  @moduledoc """
  Error struct for Apify API errors.
  """

  @type error_type ::
          :client_error
          | :server_error
          | :network_error
          | :rate_limit_error
          | :authentication_error
          | :authorization_error
          | :not_found_error
          | :validation_error
          | :conflict_error
          | :timeout_error
          | :stream_error
          | :file_error
          | :unknown_error

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          details: map()
        }

  @enforce_keys [:type, :message]
  defstruct [:type, :message, details: %{}]

  @doc """
  Creates a new error struct.
  """
  @spec new(error_type(), String.t(), map()) :: t()
  def new(type, message, details \\ %{}) do
    %__MODULE__{
      type: type,
      message: message,
      details: details
    }
  end

  @doc """
  Returns a human-readable string representation of the error.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{type: type, message: msg, details: details}) do
    base_message = "[#{type}] #{msg}"

    case details[:status_code] do
      nil -> base_message
      code -> "#{base_message} (HTTP #{code})"
    end
  end

  defimpl String.Chars do
    def to_string(error), do: ApifyClient.Error.message(error)
  end
end
