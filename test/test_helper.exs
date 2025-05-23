FootyLive.Database.initialise_disk_copies()
ExUnit.start()

# Setup Req Mock
defmodule ReqBehavior do
  @callback new(keyword()) :: Req.Request.t()
  @callback merge(Req.Request.t(), keyword()) :: Req.Request.t()
  @callback get(Req.Request.t(), keyword()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
end

Mox.defmock(ReqMock, for: ReqBehavior)
Application.put_env(:footy_live, :req_client, ReqMock)
