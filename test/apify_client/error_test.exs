defmodule ApifyClient.ErrorTest do
  use ExUnit.Case, async: true

  alias ApifyClient.Error

  describe "new/3" do
    test "creates error with type and message" do
      error = Error.new(:validation_error, "Invalid input")

      assert %Error{
               type: :validation_error,
               message: "Invalid input",
               details: %{}
             } = error
    end

    test "creates error with details" do
      details = %{status_code: 400, field: "name"}
      error = Error.new(:validation_error, "Invalid input", details)

      assert %Error{
               type: :validation_error,
               message: "Invalid input",
               details: ^details
             } = error
    end
  end

  describe "message/1" do
    test "returns formatted message without status code" do
      error = Error.new(:validation_error, "Invalid input")

      assert Error.message(error) == "[validation_error] Invalid input"
    end

    test "returns formatted message with status code" do
      error = Error.new(:validation_error, "Invalid input", %{status_code: 400})

      assert Error.message(error) == "[validation_error] Invalid input (HTTP 400)"
    end
  end

  describe "String.Chars implementation" do
    test "converts error to string" do
      error = Error.new(:rate_limit_error, "Too many requests", %{status_code: 429})

      assert to_string(error) == "[rate_limit_error] Too many requests (HTTP 429)"
    end
  end
end
