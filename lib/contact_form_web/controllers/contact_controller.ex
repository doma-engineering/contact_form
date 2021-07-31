defmodule ContactFormWeb.ContactController do
  @moduledoc """
  An endpoint that takes requests, applies an exponential rate limiting (basically banning flooders). If rate limiting is OK, it registers a form.
  """

  use ContactFormWeb, :controller
  require Logger

  defp handle(conn, _params) do
    {:ok, data, conn} = read_body(conn)
    true = byte_size(data) < 50_000
    data_json = data |> String.normalize(:nfd) |> Jason.decode!()

    message = """
    From: #{data_json["name"]} <#{data_json["email"]}>

    #{data_json["message"]}
    """

    File.mkdir("messages")
    File.write("messages/#{:os.system_time(1_000_000)}.txt", message)
    conn |> json("ok")
  end

  defp reject(conn, {_, next_allowed}),
    do: conn |> put_status(429) |> json(%{"allowedFrom" => next_allowed})

  @spec index(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def index(conn, params) do
    ip_maybe = Map.get(conn.assigns, :ip)

    if is_nil(ip_maybe) do
      msg = "IP is required for rate limiting. Perhaps you lack PublicIp plug in your endpoint?"
      Logger.error(msg)
      throw(msg)
    end

    ip = ip_maybe
    tau0 = DateTime.utc_now()

    Logger.info(
      "Anti-spam for #{ip |> String.slice(0..7)} expires at #{inspect(Cachex.ttl(:nimrod, ip))}"
    )

    {:ok, %{accept: accept, front: front, expire_at: expire_at}} =
      Cachex.transaction(:nimrod, [ip], fn sentinel ->
        {:ok, front} = Cachex.get(sentinel, ip)

        accept =
          case front do
            nil ->
              Cachex.put(sentinel, ip, next_second(), ttl: 2000)
              true

            {_, next_allowed} ->
              tau0 >= next_allowed
          end

        front1 =
          {_, tau1} =
          if accept do
            front1 = next_second()
            Cachex.update(sentinel, ip, front1)
            front1
          else
            Logger.warn("Spam from #{ip |> String.slice(0..7)} @ #{inspect(front)}")
            front1 = exponential_rate_limiter(front)
            Cachex.update(sentinel, ip, front1)
            front1
          end

        %{accept: accept, front: front1, expire_at: 1000 * (tau1 |> DateTime.to_unix()) + 1000}
      end)

    if accept do
      handle(conn, params)
    else
      Cachex.expire_at(:nimrod, ip, expire_at)
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
end
