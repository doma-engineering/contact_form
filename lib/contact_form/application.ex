defmodule ContactForm.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ContactFormWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: ContactForm.PubSub},
      # Start the Endpoint (http/https)
      {SiteEncrypt.Phoenix, ContactFormWeb.Endpoint}
      # Start a worker by calling: ContactForm.Worker.start_link(arg)
      # {ContactForm.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ContactForm.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ContactFormWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
