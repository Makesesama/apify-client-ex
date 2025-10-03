defmodule ApifyClient.HTTPClient do
  @moduledoc """
  HTTP client for making requests to the Apify API.
  Uses Req library with retry logic and proper error handling.
  """

  require Logger

  alias ApifyClient.{Config, Error}

  @type t :: %__MODULE__{
          config: Config.t(),
          req: Req.Request.t()
        }

  @enforce_keys [:config, :req]
  defstruct [:config, :req]

  @rate_limit_exceeded_status 429
  @user_agent "ApifyClient/0.1.0 (Elixir/#{System.version()})"

  @doc """
  Creates a new HTTP client instance.
  """
  @spec new(Config.t()) :: t()
  def new(%Config{} = config) do
    base_url = Config.api_url(config)

    headers = build_headers(config)

    # Get req_options from application config for test stubbing
    req_options = Application.get_env(:apify_client, :req_options, [])

    base_options = [
      base_url: base_url,
      headers: headers,
      receive_timeout: config.timeout_ms,
      max_redirects: 3
    ]

    req =
      (base_options ++ req_options)
      |> Req.new()
      |> attach_error_handler()

    %__MODULE__{
      config: config,
      req: req
    }
  end

  @doc """
  Performs a GET request.
  """
  @spec get(t(), String.t(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def get(%__MODULE__{req: req}, path, opts \\ []) do
    params = Keyword.get(opts, :params, %{})
    headers = Keyword.get(opts, :headers, [])

    req
    |> Req.get(url: path, params: params, headers: headers)
    |> handle_response()
  end

  @doc """
  Performs a POST request.
  """
  @spec post(t(), String.t(), term(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def post(%__MODULE__{req: req}, path, body, opts \\ []) do
    params = Keyword.get(opts, :params, %{})
    headers = Keyword.get(opts, :headers, [])
    content_type = Keyword.get(opts, :content_type, "application/json")

    req_opts =
      [url: path, params: params, headers: headers]
      |> add_body(body, content_type)

    req
    |> Req.post(req_opts)
    |> handle_response()
  end

  @doc """
  Performs a PUT request.
  """
  @spec put(t(), String.t(), term(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def put(%__MODULE__{req: req}, path, body, opts \\ []) do
    params = Keyword.get(opts, :params, %{})
    headers = Keyword.get(opts, :headers, [])
    content_type = Keyword.get(opts, :content_type, "application/json")

    req_opts =
      [url: path, params: params, headers: headers]
      |> add_body(body, content_type)

    req
    |> Req.put(req_opts)
    |> handle_response()
  end

  @doc """
  Performs a PATCH request.
  """
  @spec patch(t(), String.t(), term(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def patch(%__MODULE__{req: req}, path, body, opts \\ []) do
    params = Keyword.get(opts, :params, %{})
    headers = Keyword.get(opts, :headers, [])
    content_type = Keyword.get(opts, :content_type, "application/json")

    req_opts =
      [url: path, params: params, headers: headers]
      |> add_body(body, content_type)

    req
    |> Req.patch(req_opts)
    |> handle_response()
  end

  @doc """
  Performs a DELETE request.
  """
  @spec delete(t(), String.t(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def delete(%__MODULE__{req: req}, path, opts \\ []) do
    params = Keyword.get(opts, :params, %{})
    headers = Keyword.get(opts, :headers, [])

    req
    |> Req.delete(url: path, params: params, headers: headers)
    |> handle_response()
  end

  @doc """
  Performs a request for streaming data.
  Returns a Stream that yields chunks of data.
  """
  @spec stream(t(), String.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, Error.t()}
  def stream(%__MODULE__{req: req}, path, opts \\ []) do
    params = Keyword.get(opts, :params, %{})
    headers = Keyword.get(opts, :headers, [])

    stream = fn ->
      req
      |> Req.get(url: path, params: params, headers: headers, into: :self)
      |> handle_stream_response()
    end

    {:ok, Stream.resource(stream, &stream_next/1, &stream_after/1)}
  end

  # Private functions

  defp build_headers(config) do
    base_headers = [
      {"user-agent", build_user_agent(config)},
      {"accept", "application/json"}
    ]

    if config.token do
      [{"authorization", "Bearer #{config.token}"} | base_headers]
    else
      base_headers
    end
  end

  defp build_user_agent(config) do
    case config.user_agent_suffix do
      nil -> @user_agent
      suffix -> "#{@user_agent} #{suffix}"
    end
  end

  defp attach_error_handler(req) do
    Req.Request.register_options(req, [:on_error])

    Req.Request.append_error_steps(req,
      handle_http_errors: fn req ->
        case req.response do
          %Req.Response{status: status} = response when status >= 400 ->
            error = build_api_error(response)
            {req, {:error, error}}

          _ ->
            req
        end
      end
    )
  end

  defp add_body(opts, nil, _content_type), do: opts

  defp add_body(opts, body, "application/json") do
    Keyword.put(opts, :json, body)
  end

  defp add_body(opts, body, content_type) do
    opts
    |> Keyword.put(:body, body)
    |> Keyword.update(:headers, [{"content-type", content_type}], fn headers ->
      [{"content-type", content_type} | headers]
    end)
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status >= 200 and status < 300 do
    result =
      case body do
        %{"data" => data} -> data
        other -> other
      end

    {:ok, result}
  end

  defp handle_response({:ok, %Req.Response{status: 204}}) do
    {:ok, nil}
  end

  defp handle_response({:ok, %Req.Response{} = response}) do
    {:error, build_api_error(response)}
  end

  defp handle_response({:error, error}) do
    {:error, Error.new(:network_error, Exception.message(error))}
  end

  defp build_api_error(%Req.Response{status: status, body: body}) do
    {type, message} = parse_error_response(status, body)
    Error.new(type, message, %{status_code: status, body: body})
  end

  defp parse_error_response(@rate_limit_exceeded_status, body) do
    message = get_error_message(body, "Rate limit exceeded")
    {:rate_limit_error, message}
  end

  defp parse_error_response(400, body) do
    message = get_error_message(body, "Bad request")
    {:validation_error, message}
  end

  defp parse_error_response(401, body) do
    message = get_error_message(body, "Authentication failed")
    {:authentication_error, message}
  end

  defp parse_error_response(403, body) do
    message = get_error_message(body, "Access forbidden")
    {:authorization_error, message}
  end

  defp parse_error_response(404, body) do
    message = get_error_message(body, "Resource not found")
    {:not_found_error, message}
  end

  defp parse_error_response(409, body) do
    message = get_error_message(body, "Resource conflict")
    {:conflict_error, message}
  end

  defp parse_error_response(422, body) do
    message = get_error_message(body, "Validation failed")
    {:validation_error, message}
  end

  defp parse_error_response(status, body) when status >= 400 and status < 500 do
    message = get_error_message(body, "Client error")
    {:client_error, message}
  end

  defp parse_error_response(500, body) do
    message = get_error_message(body, "Internal server error")
    {:server_error, message}
  end

  defp parse_error_response(502, body) do
    message = get_error_message(body, "Bad gateway")
    {:server_error, message}
  end

  defp parse_error_response(503, body) do
    message = get_error_message(body, "Service unavailable")
    {:server_error, message}
  end

  defp parse_error_response(504, body) do
    message = get_error_message(body, "Gateway timeout")
    {:timeout_error, message}
  end

  defp parse_error_response(status, body) when status >= 500 do
    message = get_error_message(body, "Server error")
    {:server_error, message}
  end

  defp parse_error_response(_status, body) do
    message = get_error_message(body, "Unknown error")
    {:unknown_error, message}
  end

  defp get_error_message(body, default) when is_map(body) do
    body["error"]["message"] || body["error"] || body["message"] || default
  end

  defp get_error_message(body, default) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> get_error_message(decoded, default)
      {:error, _} -> body
    end
  end

  defp get_error_message(_, default), do: default

  # Stream handling functions
  defp handle_stream_response({:ok, %Req.Response{status: status}})
       when status >= 200 and status < 300 do
    receive_stream_chunks()
  end

  defp handle_stream_response({:ok, response}) do
    {:halt, {:error, build_api_error(response)}}
  end

  defp handle_stream_response({:error, error}) do
    {:halt, {:error, Error.new(:network_error, Exception.message(error))}}
  end

  defp receive_stream_chunks do
    receive do
      {_ref, {:data, data}} ->
        {[data], :continue}

      {_ref, :done} ->
        {:halt, :ok}

      {_ref, {:error, error}} ->
        {:halt, {:error, Error.new(:stream_error, Exception.message(error))}}
    after
      30_000 ->
        {:halt, {:error, Error.new(:timeout_error, "Stream timeout")}}
    end
  end

  defp stream_next(:continue), do: receive_stream_chunks()
  defp stream_next({:halt, result}), do: {:halt, result}

  defp stream_after(:ok), do: :ok
  defp stream_after({:error, _error}), do: :ok
  defp stream_after(_), do: :ok
end
