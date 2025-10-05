import Config

# Configure Reqord for testing with real API calls recorded as cassettes
config :apify_client,
  req_options: [plug: {Req.Test, ApifyClient.ReqStub}],
  # Fallback token configuration for testing (use env var if available)
  test_token: System.get_env("APIFY_TOKEN")
