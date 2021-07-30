defmodule ContactFormWeb.ContactController do
  @moduledoc """
  An endpoint that takes requests, applies an exponential rate limiting (basically banning flooders). If rate limiting is OK, it registers a form.
  """

  use ContactFormWeb, :controller

  @spec index(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def index(conn, _params) do
    require Logger
    Logger.info(Map.get(conn.assigns, :ip))
    json(conn, "ok")
  end
end
