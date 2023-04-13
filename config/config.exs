# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Import sensetive configuration
if File.exists?("config/sensetive.exs") do
  import_config "sensetive.exs"
else
  raise """
  In order for application to work properly it is required to create sensetive.exs file
  in the config directory of the project (same level with current file).
  Execute the following command from the root of the project to populate this file:

  cp config/sensetive.example.exs config/sensetive.exs

  """
end

# Configures the endpoint
config :contact_form, ContactFormWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "7inKcDnRFylgIUXEz3PwfAeDaNQv/ytSIDbA0z6nauXwviQtR0HUUOPWhEMeo2kh",
  render_errors: [view: ContactFormWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: ContactForm.PubSub,
  live_view: [signing_salt: "6L4ErvyJ"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
