# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-10-05

### Added
- Initial release of the Apify Client for Elixir
- Complete actor management (get, call, start, build, versions)
- Dataset operations (list items, stream items, download)
- Key-value store operations (get/set records, list keys)
- Request queue management (add/get/update/delete requests)
- Run monitoring and management (wait for finish, get status, abort)
- Build management and monitoring
- User account information and usage statistics
- Schedule management (CRON-based automation)
- Webhook management (event handling and testing)
- Apify Store browsing and search
- Comprehensive pagination utilities with streaming support
- Automatic retry logic with exponential backoff
- Structured error handling with 12+ specific error types
- Configuration management with environment variable support
- HTTP client based on Req library
- Memory-efficient streaming for large datasets
- Complete API coverage matching JavaScript client
- Elixir-specific enhancements:
  - `{:ok, result} | {:error, error}` tuple patterns
  - Stream processing for large data
  - Automatic pagination streaming
  - Rich typespec definitions
  - Comprehensive documentation with examples

### Features
- **Actors**: Run, manage, and monitor Apify actors
- **Datasets**: Efficiently process large datasets with streaming
- **Key-Value Stores**: Store and retrieve arbitrary data
- **Request Queues**: Manage crawling queues
- **Schedules**: Automate actor runs with CRON expressions
- **Webhooks**: Handle real-time notifications
- **User Management**: Access account info and usage statistics
- **Store Integration**: Browse and search Apify Store
- **Streaming**: Memory-efficient processing of large datasets
- **Pagination**: Automatic handling of paginated responses
- **Error Handling**: Comprehensive error types and messages
- **Retry Logic**: Automatic retries with exponential backoff

### Technical Details
- Requires Elixir 1.17+
- Uses Req for HTTP requests
- JSON processing with Jason
- Configuration validation with NimbleOptions
- Comprehensive test coverage
- Complete ExDoc documentation
- Dialyzer type checking support

[Unreleased]: https://github.com/apify/apify-client-elixir/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Makesesama/reqord/releases/tag/v0.1.0
