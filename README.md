# Apify Client for Elixir

An Elixir client library for the [Apify platform](https://apify.com/), ported from the [official JavaScript client](https://github.com/apify/apify-client-js).

[Apify](https://apify.com/) is a web scraping and automation platform that lets you turn websites into APIs. This library provides a convenient way to interact with the [Apify API](https://docs.apify.com/api/v2) from Elixir applications, with support for all major Apify resources including actors, datasets, key-value stores, request queues, and more.

## Installation

Add `apify_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:apify_client, "~> 0.1.0"}
  ]
end
```

## What is Apify?

Apify is a cloud platform for web scraping and browser automation. It provides:

- **Actors**: Ready-made scrapers and automation tools you can run in the cloud
- **Datasets**: Structured storage for scraped data
- **Proxies**: Rotating IP addresses for large-scale scraping
- **Scheduling**: Automated runs on a schedule
- **APIs**: RESTful APIs to control everything programmatically

## Quick Start

First, [sign up for a free Apify account](https://console.apify.com/sign-up) and get your API token.

```elixir
# Create a client instance with your API token
client = ApifyClient.new(token: "apify_api_YOUR_TOKEN_HERE")

# Run a web scraper actor
{:ok, run} =
  client
  |> ApifyClient.actor("apify/web-scraper")
  |> ApifyClient.Resources.Actor.call(%{
    startUrls: [%{url: "https://example.com"}],
    maxPagesPerCrawl: 10
  })

# Get the scraped data
{:ok, items} =
  client
  |> ApifyClient.dataset(run["defaultDatasetId"])
  |> ApifyClient.Resources.Dataset.list_items()

# items now contains the scraped data as a list of maps
IO.inspect(items)
```

## Configuration

You can configure the client with various options:

```elixir
client = ApifyClient.new(
  token: "YOUR_TOKEN",                    # Your Apify API token
  base_url: "https://api.apify.com",      # Base URL (default)
  timeout_ms: 60_000,                     # Request timeout (default: 360_000)
  max_retries: 5,                         # Max retries (default: 8)
  min_delay_between_retries_ms: 1000      # Min delay between retries (default: 500)
)
```

The API token can also be set via the `APIFY_TOKEN` environment variable. You can find your API token in the [Apify console](https://console.apify.com/account/integrations).

## Key Features

This library provides complete coverage of the Apify API with Elixir-specific enhancements:

### Actors (Web Scrapers & Automation Tools)
- Run any actor from the [Apify Store](https://apify.com/store)
- Pass input data and configuration options
- Monitor run status and wait for completion
- Access run logs and statistics

### Datasets (Scraped Data Storage)
- Retrieve scraped data efficiently
- Stream large datasets without memory issues
- Download data in various formats (JSON, CSV, etc.)
- Push new items to datasets

### Key-Value Stores (Simple Storage)
- Store configuration, state, or any data
- Get, set, and delete records by key
- Perfect for storing screenshots, PDFs, or JSON

### Request Queues (URL Management)
- Manage lists of URLs to scrape
- Add, get, update, and delete requests
- Track processing status

### Schedules & Webhooks (Automation)
- Schedule actors to run automatically
- Set up webhooks for real-time notifications
- Monitor and manage automated workflows

## Why Use This Library?

### Idiomatic Elixir Design
- **Pattern matching**: All functions return `{:ok, result}` or `{:error, error}` tuples
- **Streaming**: Process large datasets efficiently with Elixir's `Stream` module
- **Supervision**: Designed to work well in OTP applications
- **Concurrency**: Built for Elixir's actor model and concurrent processing

### Developer Experience
- **Complete documentation**: Full ExDoc documentation with examples
- **Type safety**: Comprehensive typespecs for better tooling and IDE support
- **Error handling**: Structured error types with detailed information
- **Testing**: Comprehensive test suite and examples

## Requirements

- Elixir 1.17+
- Apify account and API token ([sign up free](https://console.apify.com/sign-up))

## Real-World Examples

### Scraping E-commerce Product Data

```elixir
alias ApifyClient.Resources.{Actor, Dataset}

# Run Amazon product scraper
{:ok, run} =
  client
  |> ApifyClient.actor("apify/amazon-product-scraper")
  |> Actor.call(%{
    startUrls: ["https://www.amazon.com/s?k=laptops"],
    maxPagesPerCrawl: 5,
    proxy: %{useApifyProxy: true}
  })

# Wait for scraping to complete
{:ok, finished_run} =
  client
  |> ApifyClient.run(run["id"])
  |> ApifyClient.Resources.Run.wait_for_finish()

# Stream and process products efficiently
{:ok, stream} =
  client
  |> ApifyClient.dataset(run["defaultDatasetId"])
  |> Dataset.stream_items()

# Process each product as it's streamed
products =
  stream
  |> Stream.filter(fn item -> item["price"] end)
  |> Stream.map(fn item ->
    %{
      title: item["title"],
      price: item["price"],
      rating: item["rating"],
      url: item["url"]
    }
  end)
  |> Enum.take(100)

IO.puts("Found #{length(products)} products")
```

### Using Key-Value Stores for Configuration

```elixir
alias ApifyClient.Resources.KeyValueStore

# Get or create a store for your app configuration
store = ApifyClient.key_value_store(client, "my-app-config")

# Store application settings
{:ok, _} = KeyValueStore.set_record(store, "settings", %{
  notification_email: "admin@example.com",
  max_concurrent_scrapes: 5,
  retry_failed_requests: true
})

# Store a list of target URLs
{:ok, _} = KeyValueStore.set_record(store, "target-urls", [
  "https://example.com/products",
  "https://another-site.com/data"
])

# Retrieve configuration in your scraper
{:ok, settings} = KeyValueStore.get_record(store, "settings")
{:ok, urls} = KeyValueStore.get_record(store, "target-urls")

IO.puts("Will scrape #{length(urls)} URLs with max #{settings["max_concurrent_scrapes"]} concurrent requests")
```

## Advanced Features

### Processing Large Datasets Efficiently

```elixir
# Stream through millions of records without memory issues
{:ok, huge_dataset} =
  client
  |> ApifyClient.dataset("my-huge-dataset")
  |> Dataset.stream_items(limit: 1000)  # Fetch 1000 at a time

# Process and transform data efficiently
processed_count =
  huge_dataset
  |> Stream.filter(fn item -> item["price"] && item["price"] > 0 end)
  |> Stream.map(fn item ->
    # Transform and validate each item
    %{
      id: item["id"],
      name: String.trim(item["name"]),
      price: parse_price(item["price"]),
      category: normalize_category(item["category"])
    }
  end)
  |> Stream.chunk_every(500)  # Process in batches
  |> Stream.each(fn batch ->
    # Save batch to your database
    MyApp.Products.insert_batch(batch)
    IO.puts("Processed batch of #{length(batch)} items")
  end)
  |> Enum.count()

IO.puts("Processed #{processed_count} total items")
```

### Setting Up Automation

```elixir
# Schedule a scraper to run daily at 9 AM
{:ok, schedule} =
  client
  |> ApifyClient.schedules()
  |> ScheduleCollection.create(%{
    name: "daily-product-scraper",
    cronExpression: "0 9 * * *",  # 9 AM every day
    timezone: "UTC",
    actions: [%{
      type: "RUN_ACTOR",
      actorId: "apify/amazon-product-scraper",
      input: %{
        startUrls: ["https://www.amazon.com/s?k=electronics"],
        maxPagesPerCrawl: 10
      }
    }]
  })

# Set up a webhook to notify your app when scraping completes
{:ok, webhook} =
  client
  |> ApifyClient.webhooks()
  |> WebhookCollection.create(%{
    requestUrl: "https://my-app.com/api/scrape-completed",
    eventTypes: ["ACTOR.RUN.SUCCEEDED", "ACTOR.RUN.FAILED"],
    description: "Notify when daily scraping finishes"
  })

IO.puts("Automation set up! Scraper will run daily and notify your app.")
```

## Error Handling

The library provides comprehensive error handling with specific error types:

```elixir
case ApifyClient.actor(client, "my-actor") |> Actor.get() do
  {:ok, actor} ->
    IO.puts("Actor found: #{actor["name"]}")

  {:error, %ApifyClient.Error{type: :not_found_error}} ->
    IO.puts("Actor not found - check the actor ID")

  {:error, %ApifyClient.Error{type: :authentication_error}} ->
    IO.puts("Invalid API token - check your credentials")

  {:error, %ApifyClient.Error{type: :rate_limit_error}} ->
    IO.puts("Rate limit exceeded - try again later")

  {:error, %ApifyClient.Error{type: :validation_error, details: details}} ->
    IO.puts("Validation failed: #{inspect(details)}")

  {:error, error} ->
    IO.puts("Unexpected error: #{error}")
end
```

## Finding Actors in the Apify Store

```elixir
# Browse the Apify Store to find scrapers
{:ok, scrapers} =
  client
  |> ApifyClient.store()
  |> StoreCollection.list(
    search: "instagram",
    category: "SOCIAL_MEDIA",
    pricing: "FREE",
    limit: 20
  )

# Display available scrapers
scrapers["data"]["items"]
|> Enum.each(fn actor ->
  IO.puts("#{actor["name"]} by #{actor["username"]}")
  IO.puts("   #{actor["description"]}")
  IO.puts("   Pricing: #{actor["pricing"]}")
  IO.puts("")
end)
```

## Account Management

```elixir
# Check your account info and usage
{:ok, user} =
  client
  |> ApifyClient.user("me")
  |> User.get()

{:ok, usage} =
  client
  |> ApifyClient.user("me")
  |> User.monthly_usage()

IO.puts("Account: #{user["username"]}")
IO.puts("Plan: #{user["plan"]}")
IO.puts("Compute units used this month: #{usage["computeUnits"]}")
```

## Library Status

**Production Ready** with complete feature coverage:

### Core Features
- **Actors**: Run and manage any scraper from the Apify Store
- **Datasets**: Efficient data retrieval with streaming support
- **Key-Value Stores**: Simple storage for configuration and state
- **Request Queues**: URL queue management for large-scale scraping
- **Schedules**: Automated runs with cron expressions
- **Webhooks**: Real-time notifications and event handling
- **User Management**: Account info and usage monitoring

### Elixir-Specific Enhancements
- **Memory Efficient**: Stream processing for large datasets
- **Type Safe**: Comprehensive typespecs and dialyzer support
- **Fault Tolerant**: Structured error handling with specific error types
- **Concurrent**: Built for Elixir's actor model and OTP supervision
- **Idiomatic**: Uses `{:ok, result} | {:error, error}` patterns throughout

This library is **ported from and compatible with** the [official JavaScript client](https://github.com/apify/apify-client-js), ensuring consistency across different programming languages.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for new functionality
4. Run `mix test`, `mix credo`, and `mix dialyzer`
5. Submit a pull request

## License

Apache 2.0 - see LICENSE file.
