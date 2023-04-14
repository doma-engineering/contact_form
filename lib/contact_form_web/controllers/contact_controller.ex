defmodule ContactFormWeb.ContactController do
  @moduledoc """
  An endpoint that takes requests, applies an exponential rate limiting (basically banning flooders). If rate limiting is OK, it registers a form.
  """

  use ContactFormWeb, :controller
  require Logger

  alias ContactForm.Notifiers.Email

  @exponent_limit 20
  @messages_per_rolling_day 5
  @max_bytes 50_000

  defp handle(conn, params, next_allowed) do
    {:ok, data, conn} = read_body(conn)

    if byte_size(data) > @max_bytes do
      reject(conn, %{"reason" => "message too big", "maximum" => @max_bytes})
    else
      data_norm = data |> String.normalize(:nfc)

      if data_norm != data do
        reject(conn, %{"reason" => "non-unicode bytes"})
      end

      case data_norm |> Jason.decode() do
        {:ok, data_json} ->
          handle_do(conn, params, data_json, next_allowed)

        {:error, e} ->
          reject(conn, %{"reason" => "invalid JSON", "decodeError" => e |> inspect()})
      end
    end
  end

  defp handle_do(conn, _params, data_json, next_allowed) do
    {:ok, _} =
      data_json
      |> Email.new_contact_message()
      |> Email.deliver_now()

    :ok = save_to_a_file(data_json)

    conn |> json(%{"nextAllowed" => next_allowed})
  end

  defp reject(conn, %{} = e) do
    Logger.warn("Rejecting with reason #{inspect(e)}")
    conn |> put_status(400) |> json(e)
  end

  defp reject(conn, {_, next_allowed}),
    do:
      conn
      |> put_status(429)
      |> json(%{
        "allowedFrom" => next_allowed,
        "allowedPerRolling24h" => @messages_per_rolling_day
      })

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

    Logger.info("Anti-spam for #{tiny(ip)} expires at #{inspect(Cachex.ttl(:nimrod, ip))}")

    Logger.info(
      "Message quote for #{tiny(ip)} refreshes at #{inspect(Cachex.ttl(:nimrod, "#{ip}_m"))}"
    )

    {:ok, %{accept: accept, front: front, expire_at: expire_at}} =
      Cachex.transaction(:nimrod, [ip], fn sentinel ->
        update_message_counter(sentinel, ip)
        {:ok, front} = Cachex.get(sentinel, ip)

        accept =
          case front do
            nil ->
              Cachex.put(sentinel, ip, next_slot(), ttl: 60_000)
              true

            {_, next_allowed} ->
              {:ok, counter} = Cachex.get(sentinel, "#{ip}_m")

              :gt == DateTime.compare(tau0, next_allowed) && has_message_quota(counter, ip)
          end

        front1 =
          {_, tau1} =
          if accept do
            front1 = next_slot()
            Cachex.update(sentinel, ip, front1)
            front1
          else
            Logger.warn("Spam from #{tiny(ip)} @ #{inspect(front)}")
            front1 = exponential_rate_limiter(front)
            Cachex.update(sentinel, ip, front1)
            front1
          end

        %{accept: accept, front: front1, expire_at: 1000 * (tau1 |> DateTime.to_unix()) + 1000}
      end)

    if accept do
      handle(conn, params, expire_at)
    else
      Cachex.expire_at(:nimrod, ip, expire_at)
      # Cachex.expire(:nimrod, "#{ip}_m", :timer.hours(24))
      reject(conn, front)
    end
  end

  defp exponential_rate_limiter(nil), do: next_slot()

  defp exponential_rate_limiter({ticks, next_allowed}) when ticks < @exponent_limit do
    delay_base = :math.pow(2, ticks) |> round()
    multiplier = Enum.random(30..60)

    {ticks + 1,
     next_allowed
     |> DateTime.add(multiplier * delay_base)}
  end

  defp exponential_rate_limiter(x), do: x

  defp next_slot() do
    slot = Enum.random(1..5)
    {1, DateTime.utc_now() |> DateTime.add(slot)}
  end

  defp has_message_quota(nil, _) do
    true
  end

  defp has_message_quota(counter, ip) do
    if counter <= @messages_per_rolling_day do
      true
    else
      Logger.warn("Spam from #{tiny(ip)} @ #{inspect(counter)}")
      false
    end
  end

  defp update_message_counter(sentinel, ip) do
    case Cachex.get(sentinel, "#{ip}_m") do
      {:ok, nil} ->
        Cachex.put(sentinel, "#{ip}_m", 1, ttl: :timer.hours(24))

      {:ok, c} ->
        Cachex.update(sentinel, "#{ip}_m", c + 1)
    end
  end

  defp tiny(ip) do
    ip |> String.slice(0..7)
  end

  defp save_to_a_file(data_json) do
    message = """
    From: #{data_json["name"]} <#{data_json["email"]}>
    #{data_json["message"]}
    """

    Logger.info("""
    #{message}
    * * *
    """)

    file_name = "#{:os.system_time(1_000_000)}.txt"
    File.mkdir("/tmp/messages")
    File.write("/tmp/messages/#{file_name}", message)
    File.mkdir("messages")
    File.write("messages/#{file_name}", message)
  end
end
