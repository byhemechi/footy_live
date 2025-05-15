defmodule FootyLive.SquiggleTest do
  use ExUnit.Case, async: true

  import Mox

  defmodule TestError do
    defexception [:reason]

    @impl Exception
    def message(%{reason: reason}), do: "Error: #{inspect(reason)}"
  end

  defmodule TestResponse do
    defstruct [:status, :body]
  end

  setup do
    # Sets the test pid to proxy calls to the mock server, so we can verify expectations
    stub(ReqMock, :new, fn opts ->
      assert opts[:base_url] == "https://api.squiggle.au"
      assert opts[:user_agent] =~ "Elixir FootyLive"
      %Req.Request{}
    end)

    stub(ReqMock, :merge, fn %Req.Request{}, _opts -> %Req.Request{} end)

    :ok
  end

  # Helper to compare params regardless of order
  defp assert_params_match(actual, expected) do
    assert Enum.sort(actual) == Enum.sort(expected)
  end

  describe "get/1" do
    test "returns error for missing query parameter" do
      assert {:error, "Missing required :query option"} = Squiggle.get([])
    end

    test "returns error for invalid query type" do
      assert {:error, "Invalid query type: :invalid"} = Squiggle.get(query: :invalid)
    end

    test "returns error for invalid format" do
      assert {:error, "Invalid format: :invalid"} = Squiggle.get(query: :teams, format: :invalid)
    end

    test "returns error for invalid parameter" do
      assert {:error, "Invalid parameter: :invalid"} = Squiggle.get(query: :teams, invalid: true)
    end

    test "handles request errors" do
      expect(ReqMock, :get, fn %Req.Request{}, _opts ->
        {:error, %TestError{reason: :timeout}}
      end)

      assert {:error, %TestError{reason: :timeout}} = Squiggle.get(query: :teams)
    end

    test "handles non-200 responses" do
      expect(ReqMock, :get, fn %Req.Request{}, _opts ->
        {:ok, %TestResponse{status: 404}}
      end)

      assert {:error, "Unexpected response: 404"} = Squiggle.get(query: :teams)
    end
  end

  describe "get!/1" do
    test "raises on error" do
      expect(ReqMock, :get, fn %Req.Request{}, _opts ->
        {:error, %TestError{reason: :timeout}}
      end)

      assert_raise RuntimeError, ~r/Squiggle API error/, fn ->
        Squiggle.get!(query: :teams)
      end
    end
  end

  describe "teams/1" do
    test "makes request with correct parameters" do
      expect(ReqMock, :get, fn %Req.Request{}, opts ->
        assert_params_match(opts[:params], team: 1, q: :teams)
        {:ok, %TestResponse{status: 200, body: %{teams: []}}}
      end)

      assert {:ok, %{teams: []}} = Squiggle.teams(team: 1)
    end
  end

  describe "games/1" do
    test "handles multiple parameters" do
      expect(ReqMock, :get, fn %Req.Request{}, opts ->
        assert_params_match(opts[:params],
          live: 1,
          round: 1,
          year: 2024,
          q: :games
        )

        {:ok, %TestResponse{status: 200, body: %{games: []}}}
      end)

      assert {:ok, %{games: []}} = Squiggle.games(year: 2024, round: 1, live: true)
    end
  end

  describe "tips/1" do
    test "formats boolean parameters correctly" do
      expect(ReqMock, :get, fn %Req.Request{}, opts ->
        assert_params_match(opts[:params],
          complete: 100,
          source: 1,
          q: :tips
        )

        {:ok, %TestResponse{status: 200, body: %{tips: []}}}
      end)

      assert {:ok, %{tips: []}} = Squiggle.tips(source: 1, complete: 100)
    end
  end

  describe "standings/1" do
    test "handles format parameter" do
      expect(ReqMock, :get, fn %Req.Request{}, opts ->
        assert_params_match(opts[:params],
          format: :csv,
          q: :standings
        )

        {:ok, %TestResponse{status: 200, body: "team,wins,losses"}}
      end)

      assert {:ok, "team,wins,losses"} = Squiggle.standings(format: :csv)
    end
  end

  describe "ladder/1" do
    test "handles dummy parameter" do
      expect(ReqMock, :get, fn %Req.Request{}, opts ->
        assert_params_match(opts[:params],
          dummy: 1,
          q: :ladder
        )

        {:ok, %TestResponse{status: 200, body: %{ladder: []}}}
      end)

      assert {:ok, %{ladder: []}} = Squiggle.ladder(dummy: true)
    end
  end

  describe "power/1" do
    test "combines multiple parameters" do
      expect(ReqMock, :get, fn %Req.Request{}, opts ->
        assert_params_match(opts[:params],
          team: 1,
          source: 2,
          round: 3,
          q: :power
        )

        {:ok, %TestResponse{status: 200, body: %{power: []}}}
      end)

      assert {:ok, %{power: []}} = Squiggle.power(team: 1, source: 2, round: 3)
    end
  end
end
