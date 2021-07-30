defmodule ContactFormWeb.PublicIp do
  @moduledoc "Anonymise public IP address of request from x-forwarded-for header"
  @behaviour Plug
  @app :contact_form

  # Version of https://www.cogini.com/blog/getting-the-client-public-ip-address-in-phoenix/ working with a more modern Phoenix

  @spec init(list()) :: list()
  def init(opts), do: opts

  @spec anonip(
          binary
          | maybe_improper_list(
              binary | maybe_improper_list(any, binary | []) | byte,
              binary | []
            )
        ) :: String.t()
  def anonip(ip) do
    :crypto.hash(:blake2b, ip) |> Base.encode64() |> String.slice(0..71)
  end

  @spec call(Plug.Conn.t(), list()) :: Plug.Conn.t()
  def call(%{assigns: %{ip: _}} = conn, _opts) do
    conn
  end

  def call(conn, _opts) do
    xff = Plug.Conn.get_req_header(conn, "x-forwarded-for")
    result = process(conn, xff)
    result
  end

  @spec process(Plug.Conn.t(), list()) :: Plug.Conn.t()
  def process(conn, []) do
    Plug.Conn.assign(conn, :ip, to_string(:inet.ntoa(get_peer_ip(conn))))
  end

  def process(conn, vals) do
    # Rewrite standard remote_ip field with value from header
    if Application.get_env(@app, :trust_x_forwarded_for, false) do
      some_ip = get_ip_address(conn, vals)
      # See https://hexdocs.pm/plug/Plug.Conn.html
      conn = %{conn | remote_ip: some_ip}

      Plug.Conn.assign(
        conn,
        :ip,
        to_string(
          if(is_public_ip(some_ip)) do
            some_ip
          else
            to_string(:inet.ntoa(some_ip))
          end
        )
      )
    else
      [some_ip | _] = vals
      # Plug.Conn.assign(conn, :ip, to_string(:inet.ntoa(get_peer_ip(conn))))
      Plug.Conn.assign(conn, :ip, some_ip)
    end
  end

  defp get_ip_address(conn, vals)
  defp get_ip_address(conn, []), do: get_peer_ip(conn)

  defp get_ip_address(conn, [val | _]) do
    # Split into multiple values
    comps =
      val
      |> String.split(~r{\s*,\s*}, trim: true)
      # Get rid of "unknown" values
      |> Enum.filter(&(&1 != "unknown"))
      # Split IP from port, if any
      |> Enum.map(&hd(String.split(&1, ":")))
      # Filter out blanks
      |> Enum.filter(&(&1 != ""))
      # Parse address into :inet.ip_address tuple
      |> Enum.map(&parse_address(&1))
      # Elminate internal IP addreses, e.g. 192.168.1.1
      |> Enum.filter(&is_public_ip(&1))
      # Anonymise public IPs
      |> Enum.map(&anonip/1)

    case comps do
      [] -> get_peer_ip(conn)
      [some_ip | _] -> some_ip
    end
  end

  @spec get_peer_ip(Plug.Conn.t()) :: :inet.ip_address()
  defp get_peer_ip(conn) do
    %{address: ip} = conn |> Plug.Conn.get_peer_data()
    ip
  end

  @spec parse_address(String.t()) :: :inet.ip_address()
  defp parse_address(ip) do
    case :inet.parse_ipv4strict_address(to_charlist(ip)) do
      {:ok, ip_address} -> ip_address
      {:error, :einval} -> :einval
    end
  end

  # Whether the input is a valid, public IP address
  # http://en.wikipedia.org/wiki/Private_network
  @spec is_public_ip(:inet.ip_address() | atom) :: boolean
  defp is_public_ip(ip_address) do
    case ip_address do
      {10, _, _, _} -> false
      {192, 168, _, _} -> false
      {172, second, _, _} when second >= 16 and second <= 31 -> false
      {127, 0, 0, _} -> false
      {_, _, _, _} -> true
      :einval -> false
    end
  end
end
