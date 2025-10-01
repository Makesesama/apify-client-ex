defmodule ApifyClient.PaginationTest do
  use ExUnit.Case, async: true

  alias ApifyClient.Pagination

  describe "items/1" do
    test "extracts items from paginated response" do
      response = %{
        "data" => %{
          "items" => [%{"id" => "1"}, %{"id" => "2"}],
          "total" => 2
        }
      }

      assert Pagination.items(response) == [%{"id" => "1"}, %{"id" => "2"}]
    end

    test "returns empty list for invalid response" do
      assert Pagination.items(%{}) == []
      assert Pagination.items(%{"data" => %{}}) == []
    end
  end

  describe "total/1" do
    test "extracts total from paginated response" do
      response = %{
        "data" => %{
          "items" => [],
          "total" => 100
        }
      }

      assert Pagination.total(response) == 100
    end

    test "returns 0 for invalid response" do
      assert Pagination.total(%{}) == 0
      assert Pagination.total(%{"data" => %{}}) == 0
    end
  end

  describe "has_next_page?/1" do
    test "returns true when there are more pages" do
      response = %{
        "data" => %{
          "offset" => 0,
          "limit" => 10,
          "total" => 25
        }
      }

      assert Pagination.has_next_page?(response) == true
    end

    test "returns false when on last page" do
      response = %{
        "data" => %{
          "offset" => 20,
          "limit" => 10,
          "total" => 25
        }
      }

      assert Pagination.has_next_page?(response) == false
    end

    test "returns false for invalid response" do
      assert Pagination.has_next_page?(%{}) == false
    end
  end

  describe "next_page_options/1" do
    test "returns options for next page" do
      response = %{
        "data" => %{
          "offset" => 0,
          "limit" => 10,
          "total" => 25,
          "desc" => true
        }
      }

      assert Pagination.next_page_options(response) == %{
               offset: 10,
               limit: 10,
               desc: true
             }
    end

    test "returns nil when no next page" do
      response = %{
        "data" => %{
          "offset" => 20,
          "limit" => 10,
          "total" => 25
        }
      }

      assert Pagination.next_page_options(response) == nil
    end
  end
end
