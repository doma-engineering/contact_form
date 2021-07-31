defmodule ContactFormWeb.ContactController do
  @moduledoc """
  An endpoint that takes requests, applies an exponential rate limiting (basically banning flooders). If rate limiting is OK, it registers a form.
  """

  use ContactFormWeb, :controller
  require Logger

  @spec index(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def index(conn, _params) do
    ip_maybe = Map.get(conn.assigns, :ip)

    if is_nil(ip_maybe) do
      msg = "IP is required for rate limiting. Perhaps you lack PublicIp plug in your endpoint?"
      Logger.error(msg)
      throw(msg)
    end

    ip = ip_maybe
    tau0 = DateTime.utc_now()

    {:ok, {accept, front}} =
      Cachex.transaction(:nimrod, [ip], fn sentinel ->
        # Logger.warn(
        #   "locking #{inspect(ip)} @ #{inspect(DateTime.utc_now())} @ #{
        #     inspect(:crypto.hash(:blake2b, inspect(conn, limit: 10000)))
        #     |> Base.encode64()
        #     |> String.slice(0..7)
        #   }"
        # )

        {:ok, front} = Cachex.get(sentinel, ip)

        accept =
          case front do
            nil ->
              Cachex.put(sentinel, ip, next_second())
              true

            {_, next_allowed} ->
              tau0 >= next_allowed
          end

        if accept do
          Cachex.update(sentinel, ip, next_second())
        else
          Logger.warn("Spam from #{ip |> String.slice(0..7)} @ #{inspect(front)}")
          Cachex.update(sentinel, ip, exponential_rate_limiter(front))
        end

        # Logger.warn(
        #   "unlocking #{inspect(ip)} @ #{inspect(DateTime.utc_now())} @ #{
        #     inspect(:crypto.hash(:blake2b, inspect(conn, limit: 10000)))
        #     |> Base.encode64()
        #     |> String.slice(0..7)
        #   }"
        # )

        {accept, front}
      end)

    if accept do
      handle(conn)
    else
      reject(conn, front)
    end
  end

  defp exponential_rate_limiter(nil), do: next_second()

  defp exponential_rate_limiter({ticks, next_allowed}) when ticks < 20 do
    {ticks + 1,
     next_allowed
     |> DateTime.add(:math.pow(2, ticks) |> round())
     |> DateTime.add((-1 * :math.pow(2, ticks - 1)) |> round())}
  end

  defp exponential_rate_limiter(x), do: x

  defp next_second(), do: {1, DateTime.utc_now() |> DateTime.add(1)}

  defp handle(conn), do: conn |> json("ok")

  defp reject(conn, {_, next_allowed}),
    do: conn |> put_status(429) |> json(%{"allowedFrom" => next_allowed})
end
